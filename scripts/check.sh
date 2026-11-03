#!/usr/bin/env bash
# No activation or disk mutation. --static skips input fetching/evaluation.
set -Eeuo pipefail
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo"
[[ $# -eq 0 || ( $# -eq 1 && "$1" == --static ) ]] || { echo 'Usage: bash scripts/check.sh [--static]' >&2; exit 2; }
python3 -m unittest discover -s tests -v
mapfile -d '' shell_files < <(git ls-files -z -- '*.sh' 'home/ankur/hyprland/waybar/scripts/OCV')
for file in "${shell_files[@]}"; do bash -n "$file"; done
if command -v shellcheck >/dev/null; then
  # Existing UI helpers have style warnings; errors fail the repository check.
  shellcheck --severity=error "${shell_files[@]}"
  shellcheck scripts/install.sh scripts/new-host.sh scripts/check.sh
else
  echo 'SKIP ShellCheck: not installed.'
fi
if command -v nix-instantiate >/dev/null; then
  while IFS= read -r -d '' file; do nix-instantiate --parse "$file" >/dev/null; done < <(git ls-files -z -- '*.nix')
else
  echo 'SKIP native Nix parsing: nix-instantiate unavailable.'
  if python3 -c 'import tree_sitter, tree_sitter_nix' 2>/dev/null; then
    python3 tests/check_nix_syntax.py
  else
    echo 'SKIP Tree-sitter parsing: optional audit dependencies unavailable.'
  fi
fi
git diff --check
python3 tests/check_docs.py
if [[ "${1:-}" != --static ]] && command -v nix >/dev/null; then
  nix --extra-experimental-features 'nix-command flakes' flake check --no-build --no-update-lock-file
else
  echo 'SKIP flake evaluation: --static requested or Nix unavailable.'
fi
