#!/usr/bin/env python3
"""Create public ISO profiles and build ISO files. Never writes a USB or a disk."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import os
from pathlib import Path
import re
import shutil
import sys
from nixos_tools import Host, NIX, REPO, SafetyError, need_tools, nix_string, require, run


def profile_name(value):
    require(bool(re.fullmatch(r"[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?", value))
            and not value.startswith("iso-"), "Profile name must be a simple lowercase name without the iso- prefix.")
    return value


def render_profile(name, username, desktop):
    profile_name(name)
    Host("account-check", username).validate()
    require(desktop in {"minimal", "hyprland"}, "Choose minimal or hyprland.")
    return ("# Live ISO preferences only. The password is entered locally after boot.\n"
            "{ ... }: {\n  my.iso = {\n"
            f"    liveUsername = {nix_string(username)};\n"
            f"    desktop = {nix_string(desktop)};\n  }};\n}}\n")


def configure(repo, name, username, desktop, *, dry_run=False):
    text = render_profile(name, username, desktop)
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


def build(repo, name, destination):
    profile_name(name)
    output = output_directory(repo, destination)
    output.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%SZ")
    stem = f"{name}-{stamp}-{os.getpid()}"
    link = output / (stem + "-result")
    require(not link.exists() and not link.is_symlink(), "Result link already exists.")
    reference = f"{Path(repo).resolve()}#nixosConfigurations.iso-{name}.config.system.build.isoImage"
    run(NIX + ["build", "--no-update-lock-file", "--out-link", link, reference])
    images = list((link / "iso").glob("*.iso"))
    require(len(images) == 1 and images[0].is_file(), "Build returned no unique ISO under result/iso; inspect the retained result link.")
    iso, checksum = copy_iso(images[0], output / (stem + ".iso"))
    print(f"ISO: {iso}\nSHA256: {checksum}\nBuild result retained: {link}")
    print("The ISO was built and copied. No USB drive, bootloader or running system was changed.")
    return iso


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list", action="store_true", help="List available public profiles without Nix")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--profile", help="Build an existing iso-configs/NAME.nix")
    group.add_argument("--name", help="Create a new named profile, then build it")
    parser.add_argument("--username", help="Live account name; password is requested locally after boot")
    parser.add_argument("--desktop", choices=("minimal", "hyprland"))
    parser.add_argument("--output-dir", type=Path, default=Path.home() / "ISO")
    parser.add_argument("--configure-only", action="store_true", help="Create and stage a profile without building")
    parser.add_argument("--dry-run", action="store_true", help="Print choices; no file writes, staging or build")
    args = parser.parse_args(argv)
    try:
        if args.list:
            print("\n".join(p.stem for p in sorted((REPO / "iso-configs").glob("*.nix"))))
            return 0
        require(os.geteuid() != 0 or args.dry_run, "Build/configure ISOs as your normal user, without sudo.")
        if args.profile:
            require(not args.username and not args.desktop and not args.configure_only,
                    "--profile builds existing choices; use --name with username/desktop for a new configuration.")
            name = profile_name(args.profile)
            path = REPO / "iso-configs" / (name + ".nix")
            require(path.is_file() and not path.is_symlink(), f"Unknown ISO profile {name}. Use --list.")
        else:
            if not (args.name and args.username):
                require(sys.stdin.isatty(), "Supply --profile NAME, or --name NAME --username USER --desktop PROFILE.")
                args.name = args.name or input("ISO configuration name [my-live]: ").strip() or "my-live"
                args.username = args.username or input("Live username [nixos]: ").strip() or "nixos"
                args.desktop = args.desktop or input("Desktop [hyprland/minimal; default hyprland]: ").strip() or "hyprland"
                print("You will choose the live password after boot, and the installed username/password during installation.")
            name = profile_name(args.name)
            text = render_profile(name, args.username, args.desktop or "hyprland")
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
            configure(REPO, name, args.username, args.desktop or "hyprland")
        run(["git", "add", "--", str(path.relative_to(REPO))], cwd=REPO)
        if args.configure_only:
            print(f"Profile ready: {path}. Password entry happens after boot. Review and commit this public profile.")
            return 0
        build(REPO, name, args.output_dir)
        if not args.profile:
            print(f"Public profile staged: {path}. Commit it to reproduce this image configuration later.")
    except (SafetyError, OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Interrupted. Profile/build outputs retained; no USB or running system was changed.", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
