#!/usr/bin/env bash
# Default: read-only installation plan. No partitioning/formatting is implemented.
set -Eeuo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
if ! command -v python3 >/dev/null; then
  echo 'Python 3 is required. In the live USB, enter: nix-shell -p git python3' >&2
  exit 1
fi
exec python3 "$script_dir/nixos_tools.py" install "$@"
