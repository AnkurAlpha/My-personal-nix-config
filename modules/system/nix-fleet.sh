#!/usr/bin/env bash
# Built-in, non-destructive multi-host/ISO helper.
set -Eeuo pipefail
REPO="${NIX_FLEET_REPO:-$HOME/nixos-config}"
DEFAULT_OUT="${NIX_FLEET_ISO_DIR:-$HOME/ISO}"
ALLOW_HOSTS="${NIX_FLEET_HOSTS:-true}"
ALLOW_ISO="${NIX_FLEET_ISO:-true}"
ALLOW_TEMPLATE="${NIX_FLEET_TEMPLATE:-true}"
die() { echo "ERROR: $*" >&2; exit 1; }
usage() {
  cat <<'USAGE'
Usage:
  nix-fleet hosts                Show NixOS host names (read-only)
  nix-fleet iso-build [DIR] [OPTIONS]  Build ISO via the username/profile wizard
  nix-fleet template             Show the single repository manual
  nix-fleet help

ISO builds create a Nix result, a real ISO and checksum under ~/ISO (or DIR).
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
    shift
    args=(--output-dir "$DEFAULT_OUT")
    if (( $# > 0 )) && [[ "$1" != -* ]]; then
      args=(--output-dir "$1")
      shift
    fi
    exec bash "$REPO/scripts/build-iso.sh" "${args[@]}" "$@"
    ;;
  template)
    [[ "$ALLOW_TEMPLATE" == true ]] || die 'Template help disabled by its Nix switch.'
    [[ $# -eq 1 ]] || die 'Usage: nix-fleet template'
    cat "$REPO/README.md"
    ;;
  *) die "Unknown command. Try: nix-fleet help" ;;
esac
