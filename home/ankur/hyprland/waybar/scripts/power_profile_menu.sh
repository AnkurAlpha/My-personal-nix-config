#!/usr/bin/env bash
set -euo pipefail

if ! command -v wofi >/dev/null || ! command -v powerprofilesctl >/dev/null; then
  exit 0
fi

choice="$(printf '%s\n' 'Performance' 'Balanced' 'Power Saver' \
  | wofi --dmenu --prompt 'Power mode' --lines 3 --width 300 || true)"
case "$choice" in
  Performance) powerprofilesctl set performance ;;
  Balanced) powerprofilesctl set balanced ;;
  'Power Saver') powerprofilesctl set power-saver ;;
  *) exit 0 ;;
esac
