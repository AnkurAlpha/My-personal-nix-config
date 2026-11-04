#!/usr/bin/env python3
"""Create public ISO profiles and build ISO files. Never writes a USB or a disk."""
from __future__ import annotations
import argparse
import getpass
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import warnings
from nixos_tools import Host, NIX, REPO, SafetyError, need_tools, nix_string, require, run
from iso_privacy import inspect_source, snapshot

DESKTOPS = ("minimal", "hyprland", "plasma", "gnome")
HOST_FILTER = '''hosts: builtins.filter (name: name != "ankur-installer-iso" && name != "installer-iso"
  && builtins.match "iso-.*" name == null) (builtins.attrNames hosts)'''
HOST_METADATA = '''host: let c = host.config;
  users = builtins.filter (name: c.users.users.${name}.isNormalUser or false) (builtins.attrNames c.users.users);
  preferred = c.my.user.name or null;
in { system = host.pkgs.stdenv.hostPlatform.system;
  inherit users;
  defaultUser = if builtins.elem preferred users then preferred else if builtins.length users == 1 then builtins.head users else null;
  desktop = if c.programs.hyprland.enable or false then "hyprland"
    else if c.services.desktopManager.plasma6.enable or false then "plasma"
    else if c.services.desktopManager.gnome.enable or false then "gnome" else "minimal";
}'''


def profile_name(value):
    require(bool(re.fullmatch(r"[a-z](?:[a-z0-9_-]{0,61}[a-z0-9])?", value))
            and not value.startswith("iso-"),
            "Use 1-63 lowercase letters, digits, hyphens or underscores (for example my_iso or my-live); "
            "start with a letter, end with a letter/digit, and omit the reserved iso- prefix.")
    return value


def live_username(value):
    Host("account-check", value).validate()
    return value


def desktop_name(value):
    explanation = "Choose hyprland, plasma, gnome, or minimal (terminal only)."
    if value == "garuda":
        explanation = "Garuda is a Linux distribution; this builds a NixOS ISO. " + explanation
    require(value in DESKTOPS, explanation)
    return value


def prompt_value(label, default, validate):
    while True:
        value = input(f"{label} [{default}]: ").strip() or default
        try:
            return validate(value)
        except SafetyError as exc:
            print(f"Invalid choice: {exc} Please try again.", file=sys.stderr)


def desktop_input(value):
    value = value.lower()
    return desktop_name({"1": "hyprland", "2": "minimal", "3": "plasma", "4": "gnome"}.get(value, value))


def render_profile(name, username, desktop, *, source_host=None, source_user=None):
    profile_name(name)
    live_username(username)
    desktop_name(desktop)
    require(source_host is None or bool(re.fullmatch(r"[A-Za-z0-9_-]+", source_host)), "Invalid source-host name.")
    require(source_host is not None or source_user is None, "A source user requires a source host.")
    if source_user is not None:
        live_username(source_user)
    extra = (f"    sourceHost = {nix_string(source_host)};\n" if source_host is not None else "")
    extra += (f"    sourceUser = {nix_string(source_user)};\n" if source_user is not None else "")
    header = ("# Live ISO preferences only. The password is entered locally after boot.\n" if source_host is None
              else "# Public live preferences. Passwords/keys are never written to this profile.\n")
    return (header +
            "{ ... }: {\n  my.iso = {\n"
            f"    liveUsername = {nix_string(username)};\n"
            f"    desktop = {nix_string(desktop)};\n" + extra + "  };\n}\n")


def configure(repo, name, username, desktop, *, dry_run=False, source_host=None, source_user=None):
    text = render_profile(name, username, desktop, source_host=source_host, source_user=source_user)
    base = Path(repo) / "iso-configs"
    require(base.is_dir() and not base.is_symlink(), "Missing or symlinked iso-configs directory.")
    path = base / (name + ".nix")
    require(not path.is_symlink(), "Refusing a symlinked profile.")
    if path.exists():
        require(path.read_text() == text, f"Profile {name} already exists with different choices. Use another name or edit it deliberately.")
    if dry_run:
        print(text)
    elif not path.exists():
        with path.open("x") as stream:
            stream.write(text)
    return path


def available_hosts(repo):
    need_tools("nix")
    with tempfile.TemporaryDirectory(prefix="nixos-iso-hosts-") as work:
        public = Path(work) / "public"
        snapshot(repo, public)
        data = run(NIX + ["eval", "--no-update-lock-file", "--json",
                         f"path:{public}#nixosConfigurations", "--apply", HOST_FILTER], capture=True)
    names = json.loads(data)
    require(isinstance(names, list) and all(isinstance(n, str) and re.fullmatch(r"[A-Za-z0-9_-]+", n) for n in names),
            "Host discovery returned unsupported names.")
    return names


def host_metadata(repo, name):
    with tempfile.TemporaryDirectory(prefix="nixos-iso-host-info-") as work:
        public = Path(work) / "public"
        snapshot(repo, public)
        data = run(NIX + ["eval", "--no-update-lock-file", "--json",
                         f"path:{public}#nixosConfigurations", "--apply",
                         f"hosts: ({HOST_METADATA}) hosts.{nix_string(name)}"], capture=True)
    metadata = json.loads(data)
    require(metadata.get("system") == "x86_64-linux", "ISO builds currently support x86_64-linux hosts only.")
    return metadata


def choose_host(repo):
    names = available_hosts(repo)
    print("Host templates (public desktop/apps; fresh live account):\n  0) generic portable installer")
    for number, name in enumerate(names, 1):
        print(f"  {number}) {name}")
    def validate(value):
        if value in {"0", "generic"}:
            return None
        if value.isdigit() and 1 <= int(value) <= len(names):
            return names[int(value) - 1]
        require(value in names, "Choose a listed host name/number, or 0 for generic.")
        return value
    return prompt_value("Source host", names[0] if names else "generic", validate)


def password_hash():
    require(sys.stdin.isatty(), "Build-time password entry requires an interactive terminal; use --password-mode boot otherwise.")
    need_tools("mkpasswd")
    print("Use a NEW temporary live password. Its hash will be readable in this ISO/Nix store; do not reuse a personal password.")
    while True:
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("error", getpass.GetPassWarning)
                password = getpass.getpass("Temporary live password: ")
                confirmation = getpass.getpass("Confirm temporary live password: ")
        except getpass.GetPassWarning as exc:
            raise SafetyError("No echo-free terminal is available; password entry cancelled.") from exc
        if password and password == confirmation and not any(c in password for c in "\n\r\0"):
            break
        print("Passwords must be non-empty and match; please try again.", file=sys.stderr)
    result = subprocess.run(["mkpasswd", "--method=yescrypt", "--stdin"], input=password + "\n",
                            text=True, capture_output=True, check=False)
    del password, confirmation
    require(result.returncode == 0 and bool(re.fullmatch(r"\$y\$[./A-Za-z0-9$-]+", result.stdout.strip())),
            "Password hashing failed; install a yescrypt-capable mkpasswd. No password was saved.")
    return result.stdout.strip()


def preset_wrapper(public, work, name, hashed):
    private = Path(work) / "private-build"
    private.mkdir(mode=0o700)
    secret = private / "password.hash"
    with open(secret, "x", opener=lambda path, flags: os.open(path, flags, 0o600)) as stream:
        stream.write(hashed)
    (private / "flake.nix").write_text('''{
  inputs.public.url = ''' + nix_string("path:" + str(public)) + ''';
  outputs = { public, ... }: {
    packages.x86_64-linux.image = (public.nixosConfigurations.''' + nix_string("iso-" + name) + '''.extendModules {
      modules = [ { my.iso.passwordHash = builtins.readFile ./password.hash; } ];
    }).config.system.build.isoImage;
  };
}
''')
    run(NIX + ["flake", "lock", str(private)])
    expected = json.loads((Path(public) / "flake.lock").read_text())
    actual = json.loads((private / "flake.lock").read_text())
    expected_hashes = {node["locked"]["narHash"] for node in expected["nodes"].values() if "narHash" in node.get("locked", {})}
    actual_hashes = {node["locked"]["narHash"] for node in actual["nodes"].values() if "narHash" in node.get("locked", {})}
    require(expected_hashes <= actual_hashes, "Private wrapper changed a pinned input; refusing the build.")
    return f"path:{private}#image"


def clean_for_build(repo, permitted=()):
    changed = set(filter(None, run(["git", "diff", "--name-only", "-z", "HEAD", "--"], capture=True, cwd=repo).split("\0")))
    untracked = set(filter(None, run(["git", "ls-files", "--others", "--exclude-standard", "-z"], capture=True, cwd=repo).split("\0")))
    require(not (changed | untracked) - set(permitted),
            "Commit or safely save unrelated repository changes before building a reproducible ISO.")


def output_directory(repo, value):
    repo = Path(repo).resolve()
    result = Path(value).expanduser().resolve()
    require(result != repo and not result.is_relative_to(repo), "ISO output must be outside this repository.")
    for denied in ["/dev", "/proc", "/sys", "/boot", "/etc", "/nix", "/mnt/garuda", os.environ.get("NIX_FLEET_GARUDA", "/mnt/garuda")]:
        require(result != Path(denied) and not result.is_relative_to(Path(denied)), "Unsafe ISO output directory.")
    require(result != Path("/"), "Choose a directory for ISO output, not the filesystem root.")
    return result


def copy_iso(artifact, destination):
    artifact, destination = Path(artifact), Path(destination)
    # Exclusive creation protects an existing file even if its name collides.
    with artifact.open("rb") as source, destination.open("xb") as target:
        shutil.copyfileobj(source, target, length=1024 * 1024)
    digest = hashlib.sha256()
    with destination.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    checksum = destination.with_suffix(destination.suffix + ".sha256")
    with checksum.open("x") as stream:
        stream.write(f"{digest.hexdigest()}  {destination.name}\n")
    return destination, checksum


def build(repo, name, destination, *, hashed=None):
    profile_name(name)
    output = output_directory(repo, destination)
    output.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%SZ")
    stem = f"{name}-{stamp}-{os.getpid()}"
    link = output / (stem + "-result")
    require(not link.exists() and not link.is_symlink(), "Result link already exists.")
    with tempfile.TemporaryDirectory(prefix="nixos-iso-build-") as work:
        public = Path(work) / "public"
        report = snapshot(repo, public)
        reference = f"path:{public}#nixosConfigurations.iso-{name}.config.system.build.isoImage"
        if hashed is not None:
            reference = preset_wrapper(public, work, name, hashed)
        run(NIX + ["build", "--no-update-lock-file", "--out-link", link, reference])
    images = list((link / "iso").glob("*.iso"))
    require(len(images) == 1 and images[0].is_file(), "Build returned no unique ISO under result/iso; inspect the retained result link.")
    iso, checksum = copy_iso(images[0], output / (stem + ".iso"))
    report["password_mode"] = "build-time throwaway hash (public in the ISO)" if hashed is not None else "set locally on each live boot"
    manifest = output / (stem + ".source-audit.json")
    with manifest.open("x") as stream:
        json.dump(report, stream, indent=2)
    print(f"ISO: {iso}\nSHA256: {checksum}\nBuild result retained: {link}")
    print("The ISO was built and copied. No USB drive, bootloader or running system was changed.")
    print(f"Public source manifest: {manifest}")
    return iso


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list", action="store_true", help="List available public profiles without Nix")
    parser.add_argument("--list-hosts", action="store_true", help="Discover actual non-ISO NixOS host outputs")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--profile", help="Build an existing iso-configs/NAME.nix")
    group.add_argument("--name", help="Create a new profile, e.g. my_iso or my-live, then build it")
    parser.add_argument("--username", help="Live account name; password is requested locally after boot")
    parser.add_argument("--desktop", choices=DESKTOPS)
    parser.add_argument("--host", help="Existing host template, or generic for the portable installer")
    parser.add_argument("--source-user", help="Source-host account whose public desktop configuration to use")
    parser.add_argument("--password-mode", choices=("boot", "build"), help="Set a password on live boot (default), or enter a throwaway password now")
    parser.add_argument("--output-dir", type=Path, default=Path.home() / "ISO")
    parser.add_argument("--configure-only", action="store_true", help="Create and stage a profile without building")
    parser.add_argument("--dry-run", action="store_true", help="Print choices; no file writes, staging or build")
    args = parser.parse_args(argv)
    try:
        if args.list:
            print("\n".join(p.stem for p in sorted((REPO / "iso-configs").glob("*.nix"))))
            return 0
        if args.list_hosts:
            print("\n".join(available_hosts(REPO)))
            return 0
        require(os.geteuid() != 0 or args.dry_run, "Build/configure ISOs as your normal user, without sudo.")
        inspect_source(REPO)
        if args.profile:
            require(not args.username and not args.desktop and not args.configure_only and args.host is None and args.source_user is None,
                    "--profile builds existing choices; use --name with username/desktop for a new configuration.")
            name = profile_name(args.profile)
            path = REPO / "iso-configs" / (name + ".nix")
            require(path.is_file() and not path.is_symlink(), f"Unknown ISO profile {name}. Use --list.")
        else:
            name = profile_name(args.name) if args.name is not None else None
            username = live_username(args.username) if args.username is not None else None
            wizard = name is None or username is None
            selected_host = None if args.host in {None, "generic"} else args.host
            if wizard:
                require(sys.stdin.isatty(), "Supply --profile NAME, or --name NAME --username USER --desktop PROFILE.")
                print("Create a NixOS live ISO. The configuration name and live username are separate choices.")
                name = name or prompt_value("ISO configuration name (for example my_iso)", "my-live", profile_name)
                if args.host is None:
                    selected_host = choose_host(REPO)
                username = username or prompt_value("Live username", "nixos", live_username)
            if selected_host is not None:
                require(selected_host in available_hosts(REPO), "Unknown source host; use --list-hosts.")
                meta = host_metadata(REPO, selected_host)
                if args.source_user is None:
                    args.source_user = meta["defaultUser"]
                    if args.source_user is None and meta["users"]:
                        require(sys.stdin.isatty(), "This host has multiple users; select --source-user USER.")
                        args.source_user = prompt_value("Source account (" + ", ".join(meta["users"]) + ")", meta["users"][0],
                                                       lambda value: value if value in meta["users"] else require(False, "Choose a listed source user."))
                require(args.source_user is None or args.source_user in meta["users"], "Unknown source account.")
                args.desktop = args.desktop or meta["desktop"]
            else:
                require(args.source_user is None, "--source-user requires --host HOST.")
            if wizard:
                if args.desktop is None:
                    print("Desktop choices: 1) hyprland  2) minimal  3) plasma  4) gnome")
                    args.desktop = prompt_value("Desktop (number or name)", "hyprland", desktop_input)
                if args.password_mode is None and not args.configure_only:
                    args.password_mode = prompt_value("Password setup: boot (recommended) or build (throwaway password now)", "boot",
                                                      lambda value: value if value in {"boot", "build"} else require(False, "Choose boot or build."))
            text = render_profile(name, username, args.desktop or "hyprland", source_host=selected_host, source_user=args.source_user)
            path = REPO / "iso-configs" / (name + ".nix")
        output_directory(REPO, args.output_dir)
        if args.dry_run:
            if not args.profile:
                print(text)
            print(f"PLAN: build iso-{name}; output {args.output_dir}. No files changed.")
            return 0
        need_tools("git")
        if not args.configure_only:
            need_tools("nix")
            clean_for_build(REPO, [str(path.relative_to(REPO))] if not args.profile else [])
        if not args.profile:
            configure(REPO, name, username, args.desktop or "hyprland", source_host=selected_host, source_user=args.source_user)
        run(["git", "add", "--", str(path.relative_to(REPO))], cwd=REPO)
        if args.configure_only:
            print(f"Profile ready: {path}. Password entry happens after boot. Review and commit this public profile.")
            return 0
        hashed = password_hash() if args.password_mode == "build" else None
        build(REPO, name, args.output_dir, hashed=hashed)
        if not args.profile:
            print(f"Public profile staged: {path}. Commit it to reproduce this image configuration later.")
    except (SafetyError, OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except (KeyboardInterrupt, EOFError):
        print("Interrupted. Profile/build outputs retained; no USB or running system was changed.", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
