#!/usr/bin/env bash
# Read-only USB/input/Bluetooth/capture-device identification. No sudo required.
set -uo pipefail
if [[ $# -gt 0 ]]; then
  if [[ $# -eq 1 && ( "$1" == --help || "$1" == -h ) ]]; then
    printf '%s\n' 'Usage: bash scripts/gaming-device-info.sh' \
      'Connect the device by USB or pair it over Bluetooth, then run this command.' \
      'It prints device names and USB IDs. Bluetooth addresses are redacted.' \
      'A separate console that is not connected cannot be identified from this computer.'
    exit 0
  fi
  printf '%s\n' 'Usage: bash scripts/gaming-device-info.sh [--help]' >&2
  exit 2
fi

printf '%s\n' 'USB devices (vendor:product IDs and names):'
if command -v lsusb >/dev/null; then
  lsusb || printf '%s\n' 'USB enumeration was unavailable.'
else
  printf '%s\n' 'lsusb is missing; activate the removable-drive update to install usbutils.'
fi

printf '\n%s\n' 'Linux input devices (look for gamepad, controller, Xbox, Sony or Nintendo):'
if [[ -r /proc/bus/input/devices ]]; then
  awk '/^[INH]:/ { print } /^$/ { print }' /proc/bus/input/devices
else
  printf '%s\n' 'No readable Linux input-device list.'
fi

printf '\n%s\n' 'Known Bluetooth device names (addresses redacted):'
if command -v bluetoothctl >/dev/null && command -v timeout >/dev/null; then
  if ! timeout 8s bluetoothctl devices | awk '/^Device / { $2="<address>"; print }'; then
    printf '%s\n' 'Bluetooth enumeration was unavailable or timed out.'
  fi
else
  printf '%s\n' 'Bluetooth tools are unavailable; USB and input-device results are still useful.'
fi

printf '\n%s\n' 'Video/capture devices:'
shopt -s nullglob
video_names=(/sys/class/video4linux/video*/name)
if ((${#video_names[@]})); then
  for name_file in "${video_names[@]}"; do
    if [[ -r "$name_file" ]]; then
      printf '%s: ' "$(basename "$(dirname "$name_file")")"
      cat -- "$name_file"
    fi
  done
else
  printf '%s\n' 'No video capture device was listed.'
fi
printf '\n%s\n' 'If nothing identifies the device, use its model label or a photo of its front and underside.' \
  'These results do not identify a separate console connected only to a TV or a network.'
