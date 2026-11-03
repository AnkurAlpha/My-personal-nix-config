#!/usr/bin/env bash
set -Eeuo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
command -v python3 >/dev/null || { echo 'Enter nix-shell -p python3 first.' >&2; exit 1; }
exec python3 "$script_dir/nixos_tools.py" new-host "$@"
