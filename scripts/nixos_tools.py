#!/usr/bin/env python3
"""Safe new-host generation and live installation. No partition/format operations."""
from __future__ import annotations

import argparse
import contextlib
import dataclasses
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import stat
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[1]
GRAPHICS = ("none", "intel", "amd", "intel-nvidia", "amd-nvidia", "nvidia")
RESERVED = {"nixos", "installer-iso", "garuda", "templates"}
NIX = ["nix", "--extra-experimental-features", "nix-command flakes"]


class SafetyError(RuntimeError):
    pass


def require(ok, message):
    if not ok:
        raise SafetyError(message)


def run(args, *, capture=False, cwd=None, timeout=None):
    """All commands use argv arrays, never an interpolated shell."""
    try:
        result = subprocess.run([str(x) for x in args], check=True, text=True,
                                stdout=subprocess.PIPE if capture else None,
                                cwd=cwd, timeout=timeout)
        return result.stdout if capture else ""
    except FileNotFoundError as exc:
        raise SafetyError(f"Missing command: {args[0]}") from exc
    except subprocess.TimeoutExpired as exc:
        raise SafetyError(f"Command timed out: {shlex.join(map(str, args))}") from exc
    except subprocess.CalledProcessError as exc:
        raise SafetyError(f"Command failed ({exc.returncode}): {shlex.join(map(str, args))}. "
                          "Nothing will continue automatically; inspect mounts and logs before retrying.") from exc


def need_tools(*commands):
    for cmd in commands:
        require(shutil.which(cmd), f"Missing {cmd}; enter a NixOS live shell with the required tools.")


def nix_string(value):
    # JSON string literals are also Nix string literals, except Nix interpolation.
    return json.dumps(value).replace("${", r"\${")


@dataclasses.dataclass(frozen=True)
class Host:
    name: str
    username: str
    graphics: str = "none"
    desktop: str = "minimal"
    boot: str = "uefi"
    disk: str = ""
    integrated_bus_id: str = ""
    nvidia_bus_id: str = ""
    nvidia_open: bool = True
    gaming: bool = False
    bluetooth: bool = False
    power_profiles: bool = False
    timezone: str = "UTC"
    state_version: str = "26.05"
    system: str = "x86_64-linux"

    def validate(self):
        require(bool(re.fullmatch(r"[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?", self.name)) and self.name not in RESERVED,
                "Choose a NEW hostname: lowercase letters, digits and hyphens, maximum 63 characters; "
                "nixos, installer-iso, garuda and templates are reserved.")
        require(bool(re.fullmatch(r"[a-z_][a-z0-9_-]{0,30}", self.username))
                and self.username not in {"root", "nobody", "daemon"}, "Invalid regular username.")
        require(self.graphics in GRAPHICS, "Unsupported graphics selection.")
        require(self.desktop in {"minimal", "hyprland"}, "Unsupported desktop profile.")
        require(self.boot in {"uefi", "legacy"}, "Unsupported boot method.")
        require(self.system == "x86_64-linux", "This workflow currently supports x86_64-linux only.")
        require(self.state_version == "26.05", "New hosts use the pinned 26.05 initial state version; migrate older installations manually.")
        require(bool(re.fullmatch(r"[A-Za-z0-9_+/-]+", self.timezone))
                and ".." not in self.timezone and not self.timezone.startswith("/"), "Invalid timezone.")
        hybrid = self.graphics in {"amd-nvidia", "intel-nvidia"}
        for bus in (self.integrated_bus_id, self.nvidia_bus_id):
            require(not bus or bool(re.fullmatch(r"PCI:[0-9]+(?:@[0-9]+)?:[0-9]+:[0-7]", bus)),
                    "Bus IDs must use decimal NixOS syntax, for example PCI:5@0:0:0.")
        require(not hybrid or (self.integrated_bus_id and self.nvidia_bus_id
                               and self.integrated_bus_id != self.nvidia_bus_id),
                "Hybrid NVIDIA requires two distinct, verified PCI bus IDs; inspect lspci -Dnn.")
        require(hybrid or not (self.integrated_bus_id or self.nvidia_bus_id),
                "PCI PRIME bus IDs are only valid for a hybrid NVIDIA graphics selection.")
        require(self.boot != "legacy" or bool(re.fullmatch(r"/dev/[A-Za-z0-9_./:+-]+", self.disk)),
                "Legacy GRUB needs an explicitly selected whole disk under /dev/.")
        require(self.boot != "uefi" or not self.disk, "UEFI mode does not accept a legacy GRUB disk.")
        require(not self.gaming or self.graphics != "none", "Choose graphics before enabling gaming.")
        return self


def render_host(spec, root_fs):
    spec.validate()
    b = lambda value: "true" if value else "false"
    lines = ["# Generated for this machine only; review before activation.", "{ lib, ... }: {",
             "  imports = [ ./hardware-configuration.nix ../../modules/profiles/machine.nix ];",
             f"  networking.hostName = {nix_string(spec.name)};",
             f"  time.timeZone = {nix_string(spec.timezone)};", '  i18n.defaultLocale = "en_US.UTF-8";',
             f"  system.stateVersion = {nix_string(spec.state_version)};", "  my.machine = {"]
    for key, value in (("username", spec.username), ("desktop", spec.desktop), ("graphics", spec.graphics),
                       ("integratedBusId", spec.integrated_bus_id), ("nvidiaBusId", spec.nvidia_bus_id)):
        lines.append(f"    {key} = {nix_string(value)};")
    for key, value in (("nvidiaOpen", spec.nvidia_open), ("gaming.enable", spec.gaming),
                       ("bluetooth.enable", spec.bluetooth), ("powerProfiles.enable", spec.power_profiles)):
        lines.append(f"    {key} = {b(value)};")
    lines.append("  };")
    if spec.boot == "uefi":
        lines += ["  boot.loader.systemd-boot.enable = true;",
                  "  boot.loader.efi.canTouchEfiVariables = false;",
                  '  boot.loader.efi.efiSysMountPoint = "/boot";',
                  '  fileSystems."/boot".options = [ "fmask=0077" "dmask=0077" ];']
    else:
        lines += ["  boot.loader.grub.enable = true;", f"  boot.loader.grub.device = {nix_string(spec.disk)};"]
    if root_fs == "btrfs":
        lines += ["  services.btrfs.autoScrub = { enable = true; interval = \"monthly\"; fileSystems = [ \"/\" ]; };"]
    lines += ["}", ""]
    return "\n".join(lines)


def create_host(repo, spec, hardware, root_fs, *, dry_run=False):
    spec.validate()
    repo = Path(repo).resolve()
    require(root_fs in {"btrfs", "ext4", "xfs"}, "Unsupported root filesystem.")
    require((repo / "lib/hosts.nix").is_file() and (repo / "flake.nix").is_file(), "Not this configuration repository.")
    hosts = repo / "hosts"
    require(not hosts.is_symlink() and hosts.resolve().parent == repo, "Refusing symlinked host directory.")
    require("fileSystems" in hardware and "\x00" not in hardware, "Hardware input lacks filesystem configuration.")
    files = {"configuration.nix": render_host(spec, root_fs), "hardware-configuration.nix": hardware,
             "machine.json": json.dumps({"schema": 1, "root_fs": root_fs, "host": dataclasses.asdict(spec)}, indent=2) + "\n"}
    dest = hosts / spec.name
    require(not dest.is_symlink(), "Refusing symlinked host destination.")
    if dest.exists():
        require(dest.is_dir() and all((dest / n).is_file() and not (dest / n).is_symlink()
                and (dest / n).read_text() == data for n, data in files.items()),
                f"Host {spec.name} exists with different content. Review it manually; nothing overwritten.")
        return dest
    if dry_run:
        print(files["configuration.nix"])
        return dest
    # Write a complete directory before making it visible to auto-discovery.
    with tempfile.TemporaryDirectory(prefix=".new-host-", dir=repo) as temp:
        staging = Path(temp) / spec.name
        staging.mkdir()
        for name, data in files.items():
            (staging / name).write_text(data)
        staging.rename(dest)
    return dest


def flatten(items, key):
    for item in items:
        yield item
        yield from flatten((item.get(key) or []), key)


def block_inventory():
    return json.loads(run(["lsblk", "--json", "--bytes", "--output",
                           "PATH,TYPE,SIZE,FSTYPE,LABEL,MODEL,MOUNTPOINTS,PARTTYPE"], capture=True))["blockdevices"]


def inventory_report(inventory):
    print("Storage inventory (filesystem hints cannot prove whether a partition contains an OS):")
    for item in flatten(inventory, "children"):
        fs = item.get("fstype") or "-"
        hints = []
        if fs.lower() in {"ntfs", "bitlocker"}:
            hints.append("possible Windows/data; preserve")
        if fs in {"btrfs", "ext4", "xfs", "crypto_LUKS", "LVM2_member"}:
            hints.append("possible Linux/data; preserve")
        if (item.get("parttype") or "").lower() == "c12a7328-f81f-11d2-ba4b-00a0c93ec93b":
            hints.append("EFI system partition; do not format")
        print(f"  {item['path']} {item.get('type')} {item.get('size')} bytes {fs} "
              f"{item.get('label') or ''} {item.get('model') or ''} {'; '.join(hints)}")


def mounts():
    data = json.loads(run(["findmnt", "--json", "--output", "SOURCE,TARGET,FSTYPE,OPTIONS"], capture=True))
    return list(flatten(data.get("filesystems", []), "children"))


def device_of(source):
    return os.path.realpath(source.split("[", 1)[0])


def exact_mount(records, point):
    point = str(point)
    matches = [r for r in records if r["target"] == point]
    require(len(matches) == 1, f"Expected an exact mount at {point}. Mount the target filesystem explicitly.")
    return matches[0]


def block_device(path):
    try:
        return stat.S_ISBLK(Path(path).stat().st_mode)
    except OSError:
        return False


def validate_target_root(root):
    raw = Path(root)
    require(raw.is_absolute() and ".." not in raw.parts, "Target root must be an absolute path without '..'.")
    resolved = raw.resolve()
    require(str(raw) == str(resolved), "Target root cannot use symlinks.")
    require(resolved == Path("/mnt") or resolved.is_relative_to(Path("/mnt")),
            "For safety the target must be /mnt or a child of /mnt, never the running system.")
    return resolved


def validate_prepared(root, boot, records, allow_shared=False):
    root = validate_target_root(root)
    mounted = exact_mount(records, root)
    require(mounted["fstype"] in {"btrfs", "ext4", "xfs"}, "Target root must be Btrfs, ext4 or XFS, not the live root/overlay.")
    require("rw" in mounted["options"].split(","), "Target root is read-only.")
    source = device_of(mounted["source"])
    require(block_device(source), "Target root must resolve to a real block device.")
    for rec in records:
        if rec["target"] in {"/", "/home", "/nix", "/boot"}:
            require(source != device_of(rec["source"]), "Target shares a device with the running system; refusing.")
    for relative in ("etc", "home", "nix", "boot", "var", "var/log"):
        require(not (root / relative).is_symlink(), f"Target {relative} cannot be a symlink.")
    protected_sources = {device_of(r["source"]) for r in records
                         if r["target"] in {"/", "/home", "/nix", "/boot", "/iso"}}
    for rec in records:
        if rec["target"] == str(root) or rec["target"].startswith(str(root) + "/"):
            require(device_of(rec["source"]) not in protected_sources,
                    "A target mount shares storage with the running system/live media; refusing.")
    for path in (root / "etc/os-release", root / "Windows", root / "WINDOWS", root / "Users"):
        require(not path.exists(), f"Existing OS/data detected at {path}; migrate it manually instead of overwriting.")
    # Refuse installing over arbitrary personal directories on an occupied volume.
    allowed = {"home", "nix", "var", "boot", "lost+found", "etc"}
    require(not root.exists() or all(p.name in allowed for p in root.iterdir()),
            "Target root contains unrelated files/directories. Choose an empty target root/subvolume.")
    etc = root / "etc"
    require(not etc.is_symlink(), "Target /etc cannot be a symlink.")
    if etc.exists():
        require(all(p.name in {"nixos", "nixos-config"} for p in etc.iterdir()),
                "Target /etc contains existing configuration; use a new root instead of overwriting it.")
    home = root / "home"
    require(not home.is_symlink(), "Target /home cannot be a symlink.")
    if home.exists():
        require(not any(p.name != "lost+found" for p in home.iterdir()), "Target /home contains personal data; preserve it and migrate accounts manually.")
    if boot == "uefi":
        esp = exact_mount(records, root / "boot")
        require(esp["fstype"] == "vfat" and "rw" in esp["options"].split(","), "UEFI needs a writable FAT32 ESP mounted at target /boot.")
        require(device_of(esp["source"]) != source, "Root and ESP must be different filesystems.")
        require(block_device(device_of(esp["source"])), "ESP must be on a real block device.")
        require(not (root / "boot").is_symlink(), "ESP path must not be a symlink.")
        occupied = any((root / "boot").iterdir())
        require(not occupied or allow_shared,
                "ESP contains files (possibly another OS). Default is to stop. Use a dedicated ESP or review --allow-shared-esp.")
        if occupied:
            print("Existing EFI files:")
            for p in sorted((root / "boot").rglob("*.efi")):
                print(" ", p.relative_to(root / "boot"))
            print("Shared ESP: systemd-boot writes EFI/systemd, loader and may update EFI/BOOT fallback. Back up this ESP first.")
        require(shutil.disk_usage(root / "boot").free >= 256 * 1024**2, "ESP has less than 256 MiB free; make room without deleting other OS files.")
    require(shutil.disk_usage(root).free >= 8 * 1024**3, "Target root has less than 8 GiB free; desktop installations may need substantially more.")
    return mounted


def confirm(phrase):
    require(sys.stdin.isatty() and sys.stdout.isatty(), "Installation requires a local interactive terminal; confirmation cannot be piped.")
    print(f"Type exactly: {phrase}")
    require(input("> ") == phrase, "Confirmation did not match. No further changes made.")


def check_live(boot):
    require(os.geteuid() == 0, "Run installation with sudo from a NixOS live USB.")
    need_tools("nixos-install", "nixos-generate-config", "nixos-enter", "nix", "git", "findmnt", "lsblk")
    release = Path("/etc/os-release").read_text()
    require(bool(re.search(r'^ID=[\"\']?nixos[\"\']?$', release, re.M)), "Installation requires NixOS, not another distribution.")
    require(os.path.ismount("/iso") or "VARIANT_ID=installer" in release or 'VARIANT_ID="installer"' in release,
            "Cannot confirm a live NixOS installer. Boot an official NixOS live USB; no installed-system bypass is provided.")
    require(os.uname().machine == "x86_64", "Only x86_64 live environments are currently supported.")
    uefi = Path("/sys/firmware/efi").exists()
    require(uefi == (boot == "uefi"), "Boot mode mismatch: reboot the USB in the intended UEFI/legacy mode.")


def validate_disk(disk, inventory, root_source=None):
    actual = os.path.realpath(disk)
    selected = [d for d in inventory if os.path.realpath(d["path"]) == actual and d["type"] == "disk"]
    require(len(selected) == 1 and block_device(actual), "Select an existing whole disk shown by lsblk, not a partition or arbitrary path.")
    if root_source:
        require(device_of(root_source) in {device_of(d["path"]) for d in flatten(selected, "children")},
                "Legacy GRUB disk does not contain the selected target root.")
        # GRUB needs a suitable BIOS Boot Partition on GPT; let the user prepare it explicitly.
        parts = list(flatten(selected, "children"))
        require(any((p.get("parttype") or "").lower() in {"21686148-6449-6e6f-744e-656564454649", "0xef02"} for p in parts)
                or any((p.get("parttype") or "").startswith("0x") for p in parts),
                "Legacy disk needs an MBR layout or a BIOS Boot Partition on GPT; prepare it manually.")
    return selected[0]


@contextlib.contextmanager
def probe_empty_btrfs(device):
    need_tools("mount", "umount", "btrfs")
    with tempfile.TemporaryDirectory(prefix="nixos-empty-check-") as temp:
        run(["mount", "-o", "ro,nologreplay,subvolid=5", device, temp])
        try:
            require(not any(Path(temp).iterdir()), "Fresh mode requires a completely empty, already formatted Btrfs filesystem. Existing files/subvolumes found.")
            require(not run(["btrfs", "subvolume", "list", temp], capture=True).strip(), "Existing Btrfs subvolumes found; use prepared mode.")
            yield
        finally:
            run(["umount", temp])


def validate_fresh(args, records, inventory):
    root = validate_target_root(args.root)
    require(args.boot == "uefi", "Fresh preparation supports UEFI Btrfs only; use prepared mode for legacy or other layouts.")
    require(args.root_device and args.boot_device, "Fresh mode requires --root-device and --boot-device. No disk identifiers are assumed.")
    chosen = {os.path.realpath(args.root_device), os.path.realpath(args.boot_device)}
    require(len(chosen) == 2 and all(block_device(d) for d in chosen), "Select two different existing block devices.")
    devices = {device_of(d["path"]): d for d in flatten(inventory, "children")}
    require(all(d in devices for d in chosen), "Selected devices are not in lsblk inventory.")
    require(devices[os.path.realpath(args.root_device)].get("fstype") == "btrfs", "Fresh root is not Btrfs. Create/format it manually only after backup and explicit disk selection.")
    require(devices[os.path.realpath(args.boot_device)].get("fstype") == "vfat", "Fresh UEFI boot partition must already be FAT32; never format a shared ESP.")
    require(all(device_of(r["source"]) not in chosen for r in records), "A selected fresh-mode device is already mounted; inspect and unmount it manually.")
    require(not any(r["target"] == str(root) or r["target"].startswith(str(root) + "/") for r in records), "Target root already contains mounts; use prepared mode.")
    require(not root.exists() or not any(root.iterdir()), "Fresh target directory is not empty.")
    return root


def prepare_fresh(args, records, inventory):
    root = validate_fresh(args, records, inventory)
    # Probe read-only only when the user has explicitly requested installation.
    with probe_empty_btrfs(args.root_device):
        confirm(f"PREPARE {args.root_device} WITH EFI {args.boot_device}")
    root.mkdir(parents=True, exist_ok=True)
    run(["mount", "-o", "subvolid=5", args.root_device, root])
    # Recheck after switching from read-only to read-write, before writing.
    require(not any(root.iterdir()), "Root changed since inspection; stopping.")
    for sv in ("@root", "@home", "@nix", "@log"):
        run(["btrfs", "subvolume", "create", root / sv])
    run(["umount", root])
    run(["mount", "-o", "subvol=@root,compress=zstd:3,noatime", args.root_device, root])
    for directory, subvolume in (("home", "@home"), ("nix", "@nix"), ("var/log", "@log")):
        point = root / directory
        point.mkdir(parents=True, exist_ok=True)
        run(["mount", "-o", f"subvol={subvolume},compress=zstd:3,noatime", args.root_device, point])
    (root / "boot").mkdir()
    run(["mount", "-o", "fmask=0077,dmask=0077", args.boot_device, root / "boot"])
    print("Fresh mounts created. On interruption, inspect findmnt -R /mnt and resume using prepared mode; nothing is auto-unmounted.")


def spec_from(args):
    return Host(args.host, args.username, graphics=args.graphics, desktop=args.desktop, boot=args.boot,
                disk=args.disk or "", integrated_bus_id=args.integrated_bus_id or "",
                nvidia_bus_id=args.nvidia_bus_id or "", nvidia_open=not args.closed_nvidia,
                gaming=args.gaming, bluetooth=args.bluetooth, power_profiles=args.power_profiles,
                timezone=args.timezone).validate()


def install(args):
    need_tools("lsblk", "findmnt")
    records, devices = mounts(), block_inventory()
    inventory_report(devices)
    if not args.host or not args.username:
        if not sys.stdin.isatty():
            raise SafetyError("Supply --host NEW_HOST --username USER (or run interactively).")
        args.host = args.host or input("New hostname: ").strip()
        args.username = args.username or input("Regular username: ").strip()
        args.desktop = input("Desktop [minimal/hyprland; default minimal]: ").strip() or args.desktop
        args.graphics = input(f"Graphics [{'/'.join(GRAPHICS)}; default none]: ").strip() or args.graphics
        if args.graphics in {"amd-nvidia", "intel-nvidia"}:
            args.integrated_bus_id = input("Verified integrated GPU PCI bus ID (decimal): ").strip()
            args.nvidia_bus_id = input("Verified NVIDIA GPU PCI bus ID (decimal): ").strip()
    spec = spec_from(args)
    require(args.boot == "uefi" or not args.allow_shared_esp, "Shared ESP option is only meaningful for UEFI.")
    require(args.mode == "fresh" or not (args.root_device or args.boot_device),
            "Prepared mode uses existing mounts; do not supply root/boot device arguments.")
    root = validate_target_root(args.root)
    if args.boot == "legacy":
        validate_disk(args.disk, devices)
    if args.mode == "prepared":
        mounted = validate_prepared(root, args.boot, records, args.allow_shared_esp)
        print(f"Prepared root: {mounted['source']} ({mounted['fstype']}) at {root}")
    else:
        validate_fresh(args, records, devices)
        print(f"Proposed empty-Btrfs preparation: {args.root_device}; EFI: {args.boot_device}")
    print(f"Host={spec.name}, user={spec.username}, desktop={spec.desktop}, GPU={spec.graphics}, boot={spec.boot}")
    print("No formatting or partitioning commands exist in this installer. Other OS detection is advisory, not proof of absence.")
    if not args.install:
        print("PLAN ONLY: no mounts changed, host files written or system installed. Review arguments, then rerun with --install.")
        return
    check_live(args.boot)
    require(sys.stdin.isatty() and sys.stdout.isatty(), "--install requires a local interactive terminal.")
    # A network check through Git uses the same transport as the repository.
    run(["git", "ls-remote", "--exit-code", "https://github.com/NixOS/nixpkgs.git", "HEAD"], capture=True, timeout=45)
    require(not run(["git", "status", "--porcelain"], capture=True, cwd=REPO).strip(),
            "Source checkout must be clean and committed; clone/copy installation will not silently omit edits.")
    if args.mode == "fresh":
        prepare_fresh(args, records, devices)
    mounted = validate_prepared(root, args.boot, mounts(), args.allow_shared_esp)
    if args.boot == "legacy":
        validate_disk(args.disk, devices, mounted["source"])
    phrase = f"INSTALL {spec.name} AT {root}"
    if args.boot == "legacy":
        phrase += f" REPLACE GRUB ON {args.disk}"
    if args.allow_shared_esp:
        phrase += " UPDATE SHARED EFI"
    confirm(phrase)
    target = root / "etc/nixos-config"
    require(not (root / "etc").is_symlink() and not target.is_symlink(), "Refusing symlinked target configuration paths.")
    marker = target / ".install-state.json"
    require(not marker.is_symlink(), "Refusing symlinked installer state.")
    revision = run(["git", "rev-parse", "HEAD"], capture=True, cwd=REPO).strip()
    state = {"schema": 1, "source_revision": revision, "root_source": mounted["source"], "host": dataclasses.asdict(spec)}
    if target.exists():
        require(args.resume and marker.is_file() and json.loads(marker.read_text()) == state,
                f"{target} exists. Nothing overwritten. --resume is only accepted for an identical installer-managed attempt.")
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        run(["git", "clone", "--no-hardlinks", REPO, target])
        origin = run(["git", "remote", "get-url", "origin"], capture=True, cwd=REPO).strip()
        require(not re.search(r"https?://[^/]*@", origin), "Source origin embeds credentials; remove them before installation.")
        run(["git", "remote", "set-url", "origin", origin], cwd=target)
        marker.write_text(json.dumps(state, indent=2) + "\n")
        with (target / ".git/info/exclude").open("a") as stream:
            stream.write("\n.install-state.json\n")
    # --show-hardware-config prints to stdout, preserving any /etc/nixos files.
    hardware = run(["nixos-generate-config", "--root", root, "--show-hardware-config"], capture=True)
    dest = create_host(target, spec, hardware, mounted["fstype"])
    run(["git", "add", "--", str(dest.relative_to(target))], cwd=target)
    ref = f"{target}#nixosConfigurations.{spec.name}.config"
    evaluated_host = run(NIX + ["eval", "--no-update-lock-file", "--raw", ref + ".networking.hostName"], capture=True).strip()
    require(evaluated_host == spec.name, "Evaluated hostname differs from the selected host; refusing installation.")
    errors = json.loads(run(NIX + ["eval", "--no-update-lock-file", "--json", "--apply",
        "xs: map (x: x.message) (builtins.filter (x: !x.assertion) xs)", ref + ".assertions"], capture=True))
    require(not errors, "NixOS assertions failed: " + "; ".join(errors))
    run(NIX + ["build", "--no-update-lock-file", "--no-link", ref + ".system.build.toplevel"])
    # nixos-install handles a root password prompt; regular user uses passwd below.
    run(["nixos-install", "--root", root, "--flake", f"{target}#{spec.name}", "--no-channel-copy"])
    run(["nixos-enter", "--root", root, "-c", f"passwd {spec.username}"])
    print(f"Installed {spec.name}. Keep the USB available; review {target}, boot files and firmware selection before rebooting.")
    print("No reboot, unmount, push, secret copy or cleanup was performed. Commit generated host files after first-boot verification.")


def common(parser):
    parser.add_argument("--host")
    parser.add_argument("--username")
    parser.add_argument("--graphics", choices=GRAPHICS, default="none")
    parser.add_argument("--desktop", choices=("minimal", "hyprland"), default="minimal")
    parser.add_argument("--boot", choices=("uefi", "legacy"), default="uefi")
    parser.add_argument("--disk", help="Explicit whole disk for legacy GRUB only")
    parser.add_argument("--integrated-bus-id")
    parser.add_argument("--nvidia-bus-id")
    parser.add_argument("--closed-nvidia", action="store_true", help="Older NVIDIA hardware; verify driver support first")
    parser.add_argument("--gaming", action="store_true")
    parser.add_argument("--bluetooth", action="store_true")
    parser.add_argument("--power-profiles", action="store_true")
    parser.add_argument("--timezone", default="UTC")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    new = sub.add_parser("new-host", help="Create a host without changing flake.nix or existing hosts")
    common(new)
    new.add_argument("--hardware", type=Path, required=True)
    new.add_argument("--root-fs", choices=("btrfs", "ext4", "xfs"), required=True)
    new.add_argument("--dry-run", action="store_true")
    inst = sub.add_parser("install", help="Read-only plan by default; --install requires local confirmation")
    common(inst)
    inst.add_argument("--root", default="/mnt")
    inst.add_argument("--mode", choices=("prepared", "fresh"), default="prepared")
    inst.add_argument("--root-device")
    inst.add_argument("--boot-device")
    inst.add_argument("--allow-shared-esp", action="store_true", help="Opt into reviewed shared EFI updates; may replace the fallback loader")
    inst.add_argument("--install", action="store_true")
    inst.add_argument("--resume", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.action == "new-host":
            require(args.host and args.username, "--host and --username are required.")
            dest = create_host(REPO, spec_from(args), args.hardware.read_text(), args.root_fs, dry_run=args.dry_run)
            print(f"{'Preview' if args.dry_run else 'Host ready'}: {dest}. Stage hosts/{args.host} before Git-flake evaluation.")
        else:
            install(args)
    except (SafetyError, OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Interrupted. No automatic rollback/unmount. Inspect target mounts and retain the USB before retrying.", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    sys.exit(main())
