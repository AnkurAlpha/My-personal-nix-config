#!/usr/bin/env bash
# Usage: nix-dev [list|help|LANGUAGE [-- COMMAND...]]
set -Eeuo pipefail
repo="${NIX_DEV_FLAKE:-$HOME/nixos-config}"
usage() {
  cat <<'HELP'
nix-dev list                      List enabled development shells
nix-dev cpp                       Open C/C++ shell (example)
nix-dev python -- python --version Run a command inside Python shell
nix-dev help                      Show this information

Shells are pinned by ~/nixos-config/flake.lock. No global compilers or
language servers are added by entering or leaving the shell.
HELP
}
[[ -f "$repo/flake.nix" ]] || { echo "Missing flake: $repo" >&2; exit 1; }
case "${1:-help}" in
  help|-h|--help) usage; exit 0 ;;
  list)
    [[ $# -eq 1 ]] || { echo 'Usage: nix-dev list' >&2; exit 2; }
    exec nix eval --no-write-lock-file --json --apply builtins.attrNames "$repo#devShells.x86_64-linux"
    ;;
esac
name="$1"
shift
case "$name" in
  default|cpp|python|rust|node|java|clang|go|fullstack) ;;
  *) echo "Unknown environment: $name (try nix-dev list)" >&2; exit 2 ;;
esac
if [[ "${1:-}" == '--' ]]; then shift; fi
if (( $# > 0 )); then
  exec nix develop --no-write-lock-file "$repo#$name" --command "$@"
else
  exec nix develop --no-write-lock-file "$repo#$name"
fi
