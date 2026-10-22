#!/usr/bin/env bash
# Built-in, non-destructive multi-host/ISO helper.
set -Eeuo pipefail
REPO="${NIX_FLEET_REPO:-$HOME/nixos-config}"
GARUDA="${NIX_FLEET_GARUDA:-/mnt/garuda}"
DEFAULT_OUT="${NIX_FLEET_ISO_DIR:-$HOME/ISO}"
ALLOW_HOSTS="${NIX_FLEET_HOSTS:-true}"
ALLOW_ISO="${NIX_FLEET_ISO:-true}"
ALLOW_TEMPLATE="${NIX_FLEET_TEMPLATE:-true}"
die() { echo "ERROR: $*" >&2; exit 1; }
usage() {
  cat <<'USAGE'
Usage:
  nix-fleet hosts                Show NixOS host names (read-only)
  nix-fleet iso-build [DIR]      Build ISO manually and make a dated result link
  nix-fleet template             Explain how to register a second computer
  nix-fleet help

ISO builds only create Nix store paths and a result symlink under ~/ISO (or DIR).
No USB formatting, writes to /mnt/garuda, auto updates or activation occurs.
USAGE
}
[[ "$EUID" -ne 0 ]] || die 'Run as a normal user (never sudo).'
[[ -f "$REPO/flake.nix" && -f "$REPO/flake.lock" ]] || die "Flake not found: $REPO"
case "${1:-help}" in
  help|-h|--help) usage ;;
  hosts)
    [[ "$ALLOW_HOSTS" == true ]] || die 'Host inspection is disabled by its Nix switch.'
    [[ $# -eq 1 ]] || die 'Usage: nix-fleet hosts'
    nix eval --no-write-lock-file --json --apply 'builtins.attrNames' "$REPO#nixosConfigurations"
    printf '\n'
    ;;
  iso-build)
    [[ "$ALLOW_ISO" == true ]] || die 'ISO building is disabled by its Nix switch.'
    [[ $# -le 2 ]] || die 'Usage: nix-fleet iso-build [directory]'
    for cmd in nix git realpath mkdir date; do command -v "$cmd" >/dev/null || die "Missing: $cmd"; done
    [[ -z "$(git -C "$REPO" status --porcelain --untracked-files=normal)" ]] || die 'Commit/stash repo changes first, to get a reproducible ISO.'
    output="$(realpath -m "${2:-$DEFAULT_OUT}")"
    repo_real="$(realpath -e "$REPO")"
    garuda_real="$(realpath -m "$GARUDA")"
    [[ "$output" != "$repo_real" && "$output" != "$repo_real/"* ]] || die 'ISO output must be outside your Git repo.'
    [[ "$output" != "$garuda_real" && "$output" != "$garuda_real/"* ]] || die 'Garuda is read-only reference, not an ISO destination.'
    mkdir -p -- "$output"
    stamp="$(date +%Y%m%d-%H%M%S)"
    link="$output/ankur-installer-iso-$stamp-$$"
    [[ ! -e "$link" && ! -L "$link" ]] || die "Output exists: $link"
    echo "Building an x86_64 minimal installer ISO from the pinned flake; this may require substantial disk space."
    nix build --no-write-lock-file --out-link "$link" "$REPO#nixosConfigurations.ankur-installer-iso.config.system.build.isoImage"
    [[ -d "$link/iso" ]] || die "Build finished but no ISO directory was found at $link/iso"
    printf '\nISO created; locate it under:\n  %s/iso/\n' "$link"
    find "$link/iso" -maxdepth 1 -type f -name '*.iso' -print
    echo 'No USB drive was written.'
    ;;
  template)
    [[ "$ALLOW_TEMPLATE" == true ]] || die 'Template help disabled by its Nix switch.'
    [[ $# -eq 1 ]] || die 'Usage: nix-fleet template'
    cat "$REPO/hosts/templates/README.md"
    ;;
  *) die "Unknown command. Try: nix-fleet help" ;;
esac
