#!/usr/bin/env bash
# Read-only aggregate traffic for Waybar; omit loopback unless explicitly selected.
set -euo pipefail
fail() { printf '{"text":"⚠ network","tooltip":"%s","class":"error"}\n' "$1"; exit 2; }
interval=1
while getopts ':t:' opt; do
  case "$opt" in
    t) interval="$OPTARG" ;;
    *) fail 'Usage: network_traffic.sh [-t SECONDS] [INTERFACE ...]' ;;
  esac
done
shift "$((OPTIND - 1))"
[[ "$interval" =~ ^[1-9][0-9]*$ && ${#interval} -le 6 ]] || fail 'Polling interval must be a positive integer.'
rate_max="${rate_max:-1000000}"
[[ "$rate_max" =~ ^[1-9][0-9]*$ && ${#rate_max} -le 12 ]] || fail 'rate_max must be a positive integer.'
ifaces=("$@")
if (( ${#ifaces[@]} == 0 )); then
  for path in /sys/class/net/*; do
    name="${path##*/}"
    [[ "$name" == lo ]] || ifaces+=("$name")
  done
fi
declare -A old_rx old_tx
for iface in "${ifaces[@]}"; do
  [[ "$iface" =~ ^[A-Za-z0-9_][A-Za-z0-9_.:-]{0,14}$ ]] || fail 'Invalid interface name.'
  [[ -r "/sys/class/net/$iface/statistics/rx_bytes" && -r "/sys/class/net/$iface/statistics/tx_bytes" ]] || fail 'Selected interface is unavailable.'
  old_rx["$iface"]="$(<"/sys/class/net/$iface/statistics/rx_bytes")"
  old_tx["$iface"]="$(<"/sys/class/net/$iface/statistics/tx_bytes")"
done
human() {
  local value="$1" unit=0
  local units=(B K M G T P)
  while (( value >= 1000 && unit < 5 )); do value=$((value / 1000)); unit=$((unit + 1)); done
  printf '%s%s' "$value" "${units[$unit]}"
}
while sleep "$interval"; do
  total_rx=0 total_tx=0
  for iface in "${ifaces[@]}"; do
    # Hot-unplugged devices are skipped without inventing a counter spike.
    [[ -r "/sys/class/net/$iface/statistics/rx_bytes" && -r "/sys/class/net/$iface/statistics/tx_bytes" ]] || continue
    rx="$(<"/sys/class/net/$iface/statistics/rx_bytes")"
    tx="$(<"/sys/class/net/$iface/statistics/tx_bytes")"
    delta_rx=$(((rx - old_rx[$iface]) / interval))
    delta_tx=$(((tx - old_tx[$iface]) / interval))
    (( delta_rx >= 0 )) || delta_rx=0
    (( delta_tx >= 0 )) || delta_tx=0
    total_rx=$((total_rx + delta_rx))
    total_tx=$((total_tx + delta_tx))
    old_rx["$iface"]="$rx" old_tx["$iface"]="$tx"
  done
  percent=$(((total_rx + total_tx) * 100 / rate_max))
  (( percent <= 100 )) || percent=100
  printf '{"text":"%4s⇣ %4s⇡","tooltip":"","percentage":%d}\n' "$(human "$total_rx")" "$(human "$total_tx")" "$percent"
done
