#!/usr/bin/env bash
# WiFi Auto-Recover Watchdog for Raspberry Pi
# - Detects WLAN interface automatically
# - Verifies association + internet reachability
# - If offline, cycles WiFi every 60s until back online
# - Logs recovery events (start, duration, success) to ~/wifi_recovery.log
# - Logs runtime status to /var/log/wifi_auto_recover.log via systemd

set -euo pipefail

# --- Settings ---
PING_HOSTS=("1.1.1.1" "8.8.8.8")   # IPs to test internet reachability
PING_TIMEOUT=2                     # seconds per ping
CHECK_INTERVAL_OK=15               # seconds between healthy checks
RETRY_INTERVAL=60                  # seconds between recovery cycles
MAX_FAILS=1                        # trigger recovery after this many fails

HOME_LOG="${HOME}/wifi_recovery.log"

detect_iface() {
  if [[ $# -gt 0 && -n "${1:-}" ]]; then
    echo "$1"
    return
  fi
  local first
  first="$(iw dev | awk '/Interface/ {print $2; exit}')"
  if [[ -z "$first" ]]; then
    echo "No wireless interface found" >&2
    exit 1
  fi
  echo "$first"
}

IFACE="$(detect_iface "${1:-}")"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [wifi-auto-recover] $*" | tee -a /var/log/wifi_auto_recover.log
}

userlog() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [wifi-recovery] $*" >> "$HOME_LOG"
}

check_association() {
  iw dev "$IFACE" link | grep -q "Connected to"
}

check_internet() {
  for h in "${PING_HOSTS[@]}"; do
    if ping -I "$IFACE" -c 1 -W "$PING_TIMEOUT" "$h" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

disable_powersave() {
  if iw dev "$IFACE" get power_save 2>/dev/null | grep -qi on; then
    iw dev "$IFACE" set power_save off || true
    log "Disabled WiFi power save on $IFACE"
  fi
}

cycle_wifi() {
  log "Cycling WiFi on $IFACE (down → up)"
  ip link set "$IFACE" down || true
  sleep 2
  ip link set "$IFACE" up || true
  if command -v wpa_cli >/dev/null 2>&1; then
    wpa_cli -i "$IFACE" reconfigure >/dev/null 2>&1 || true
  fi
}

report_status() {
  local ssid ipaddr
  ssid="$(iwgetid -r 2>/dev/null || echo '?')"
  ipaddr="$(ip -4 addr show dev "$IFACE" | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)"
  log "Status: SSID=${ssid}, IP=${ipaddr:-none}"
}

main() {
  log "Starting WiFi Auto-Recover on interface: $IFACE"
  disable_powersave
  report_status

  local fails=0
  local recovery_start=0

  while true; do
    if check_association && check_internet; then
      # Connected
      if (( recovery_start > 0 )); then
        local recovery_end
        recovery_end=$(date +%s)
        local duration=$((recovery_end - recovery_start))
        userlog "Recovered connection on $IFACE after ${duration}s."
        log "✅ Connectivity restored after ${duration}s."
        report_status
        recovery_start=0
      fi
      fails=0
      sleep "$CHECK_INTERVAL_OK"
      continue
    fi

    # Not connected
    ((fails++))
    log "Connectivity check failed (${fails}/${MAX_FAILS})."
    report_status

    if (( fails >= MAX_FAILS )); then
      if (( recovery_start == 0 )); then
        recovery_start=$(date +%s)
        userlog "Lost connection on $IFACE — starting recovery attempts."
      fi
      cycle_wifi
      sleep "$RETRY_INTERVAL"
    else
      sleep 5
    fi
  done
}

main
