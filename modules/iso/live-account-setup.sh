#!/usr/bin/env bash
# Invoked by the live ISO's root-only console service, before any login session.
set -Eeuo pipefail
[[ "$EUID" -eq 0 && $# -eq 2 ]] || { echo 'Use the live-user-setup system service.' >&2; exit 1; }
username="$1"
mode="$2"
[[ "$username" =~ ^[a-z_][a-z0-9_-]{0,30}$ && "$username" != root && "$username" != nobody && "$username" != daemon ]] || exit 1
[[ "$mode" == boot || "$mode" == preset ]] || exit 1
[[ ! -e /run/live-account-ready ]] || exit 0
export LC_ALL=C
if [[ "$mode" == boot ]]; then
  printf '\nSet a password for live account %s.\n' "$username"
  printf 'This is separate from the installed account password.\n'
  while true; do
    if passwd "$username"; then
      status="$(passwd -S "$username")"
      case "$status" in "$username P "*) break ;; esac
    fi
    printf '\nSet a non-empty usable password to finish live-session setup.\n'
  done
else
  status="$(passwd -S "$username")"
  case "$status" in
    "$username P "*) printf 'Live account %s uses the temporary password chosen when building this image.\n' "$username" ;;
    *) echo 'The preset live password is unusable; refusing to unlock login.' >&2; exit 1 ;;
  esac
fi
touch /run/live-account-ready
