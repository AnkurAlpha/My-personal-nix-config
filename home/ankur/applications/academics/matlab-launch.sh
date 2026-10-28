#!/usr/bin/env bash
# Runs INSIDE the matlab-fhs compatibility environment.
# MATLAB_ROOT can select an existing install, e.g. MATLAB_ROOT=/opt/MATLAB/R2026b matlab
set -euo pipefail

candidate=""
if [[ -n "${MATLAB_ROOT:-}" ]]; then
  if [[ -x "$MATLAB_ROOT/bin/matlab" ]]; then
    candidate="$MATLAB_ROOT/bin/matlab"
  else
    echo "MATLAB_ROOT is set, but $MATLAB_ROOT/bin/matlab is not executable." >&2
    exit 127
  fi
else
  # Only read installation folders; never write to Garuda or system directories.
  for base in "$HOME/MATLAB" "$HOME/.local/share/MATLAB" /usr/local/MATLAB /opt/MATLAB; do
    [[ -d "$base" ]] || continue
    if [[ -x "$base/bin/matlab" ]]; then candidate="$base/bin/matlab"; break; fi
    while IFS= read -r dir; do
      if [[ -x "$dir/bin/matlab" ]]; then candidate="$dir/bin/matlab"; break; fi
    done < <(find "$base" -mindepth 1 -maxdepth 1 -type d -name 'R20*' 2>/dev/null | sort -Vr)
    [[ -z "$candidate" ]] || break
  done
fi

if [[ -z "$candidate" ]]; then
  cat >&2 <<'EOF'
MATLAB integration is enabled, but a MATLAB installation was not found.
Download and install MATLAB for Linux using your licensed MathWorks account:
  https://www.mathworks.com/downloads/
Use a user-writable folder such as ~/MATLAB/R2026b or the MathWorks default.
Then launch using:  matlab
For a custom installation location:
  MATLAB_ROOT=/absolute/path/to/MATLAB/R20XXy matlab
For installation on NixOS, see: https://wiki.nixos.org/wiki/Matlab
EOF
  exit 127
fi

exec "$candidate" "$@"
