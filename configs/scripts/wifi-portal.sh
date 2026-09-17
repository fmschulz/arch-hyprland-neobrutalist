#!/bin/bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/wifi-portal"
STAMP_FILE="${STATE_DIR}/last-launch"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/wifi-portal.lock"
THROTTLE_SECONDS="${WIFI_PORTAL_THROTTLE_SECONDS:-90}"
FALLBACK_URL="${WIFI_PORTAL_FALLBACK_URL:-http://neverssl.com/}"
STABLE_SECONDS="${WIFI_PORTAL_STABLE_SECONDS:-8}"
POLL_INTERVAL_SECONDS="${WIFI_PORTAL_POLL_INTERVAL_SECONDS:-2}"
MAX_WAIT_SECONDS="${WIFI_PORTAL_MAX_WAIT_SECONDS:-45}"

usage() {
  cat <<'EOF'
Usage: wifi-portal.sh [open|monitor|status]

open    Open a captive-portal login window for the active Wi-Fi network.
monitor Watch NetworkManager and auto-open the login window when Wi-Fi
        connectivity becomes portal/limited.
status  Print the active Wi-Fi network and connectivity state.
EOF
}

trim() {
  sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

active_wifi_device() {
  nmcli -t -f DEVICE,TYPE,STATE device status |
    awk -F: '$2 == "wifi" && $3 == "connected" { print $1; exit }'
}

nm_field() {
  local device=$1
  local field=$2
  nmcli -t -f "$field" device show "$device" |
    sed -En "s/^${field}(\\[[0-9]+\\])?://p" |
    head -n1 |
    trim
}

active_bssid() {
  local device=$1
  iw dev "$device" link 2>/dev/null | sed -n 's/Connected to //p' | awk '{print $1}'
}

active_snapshot() {
  local device connection bssid gw dns

  device=$(active_wifi_device || true)
  [[ -n "$device" ]] || return 1

  connection=$(nm_field "$device" GENERAL.CONNECTION)
  [[ -n "$connection" && "$connection" != "--" ]] || return 1

  bssid=$(active_bssid "$device")
  gw=$(nm_field "$device" IP4.GATEWAY)
  dns=$(nm_field "$device" IP4.DNS)
  [[ -n "$gw" ]] || return 1

  printf '%s|%s|%s|%s|%s\n' "$device" "$connection" "$bssid" "$gw" "$dns"
}

connectivity_name() {
  local device=$1
  local raw parsed

  raw=$(nm_field "$device" GENERAL.IP4-CONNECTIVITY)
  if [[ -z "$raw" ]]; then
    nmcli networking connectivity 2>/dev/null || echo unknown
    return
  fi

  parsed=$(sed -n 's/.*(\([^)]*\)).*/\1/p' <<<"$raw")
  if [[ -n "$parsed" ]]; then
    printf '%s\n' "$parsed"
  else
    printf '%s\n' "$raw"
  fi
}

wait_for_stable_wifi() {
  local target_connection=${1:-}
  local required_samples deadline last_snapshot current_snapshot current_connection state stable_samples

  if (( POLL_INTERVAL_SECONDS <= 0 )); then
    required_samples=1
  else
    required_samples=$((STABLE_SECONDS / POLL_INTERVAL_SECONDS))
    (( required_samples > 0 )) || required_samples=1
  fi

  deadline=$(( $(date +%s) + MAX_WAIT_SECONDS ))
  last_snapshot=""
  stable_samples=0

  while (( $(date +%s) < deadline )); do
    current_snapshot=$(active_snapshot || true)

    if [[ -z "$current_snapshot" ]]; then
      stable_samples=0
      last_snapshot=""
      sleep "$POLL_INTERVAL_SECONDS"
      continue
    fi

    current_connection=$(cut -d'|' -f2 <<<"$current_snapshot")
    if [[ -n "$target_connection" && "$current_connection" != "$target_connection" ]]; then
      stable_samples=0
      last_snapshot=""
      sleep "$POLL_INTERVAL_SECONDS"
      continue
    fi

    state=$(nmcli networking connectivity 2>/dev/null || true)
    if [[ "$state" == "disconnected" ]] || [[ "$state" == "unknown" ]]; then
      stable_samples=0
      last_snapshot=""
      sleep "$POLL_INTERVAL_SECONDS"
      continue
    fi

    if [[ "$current_snapshot" == "$last_snapshot" ]]; then
      ((stable_samples += 1))
    else
      stable_samples=1
      last_snapshot="$current_snapshot"
    fi

    if (( stable_samples >= required_samples )); then
      return 0
    fi

    sleep "$POLL_INTERVAL_SECONDS"
  done

  return 1
}

show_status() {
  local device=$1
  local connection=$2
  local state=$3
  local bssid=$4
  local ip4=$5
  local gw=$6

  echo "Wi-Fi device: ${device}"
  echo "Connection: ${connection:-<none>}"
  echo "Connectivity: ${state:-unknown}"
  echo "BSSID: ${bssid:-<unknown>}"
  echo "IPv4: ${ip4:-<none>}"
  echo "Gateway: ${gw:-<none>}"
}

notify_portal() {
  local title=$1
  local body=$2

  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$body" -t 5000
  fi
}

record_launch() {
  local connection=$1
  local bssid=$2
  local state=$3

  mkdir -p "$STATE_DIR"
  printf '%s|%s|%s|%s\n' "$(date +%s)" "$connection" "$bssid" "$state" >"$STAMP_FILE"
}

recent_launch_matches() {
  local connection=$1
  local bssid=$2
  local now ts last_connection last_bssid _last_state

  [[ -f "$STAMP_FILE" ]] || return 1

  IFS='|' read -r ts last_connection last_bssid _last_state <"$STAMP_FILE" || return 1
  now=$(date +%s)

  [[ "$connection" == "$last_connection" ]] || return 1
  [[ -n "$bssid" && "$bssid" == "$last_bssid" ]] || [[ -z "$bssid" && -z "$last_bssid" ]] || return 1
  (( now - ts < THROTTLE_SECONDS ))
}

launch_default_browser() {
  if command -v xdg-open >/dev/null 2>&1; then
    setsid -f xdg-open "$FALLBACK_URL" >/dev/null 2>&1
    return 0
  fi

  if command -v gio >/dev/null 2>&1; then
    setsid -f gio open "$FALLBACK_URL" >/dev/null 2>&1
    return 0
  fi

  return 1
}

open_portal() {
  local mode=${1:-manual}
  local device connection state bssid message ip4 gw

  device=$(active_wifi_device || true)
  if [[ -z "$device" ]]; then
    echo "No active Wi-Fi connection found" >&2
    notify_portal "Wi-Fi login" "No active Wi-Fi connection found."
    return 1
  fi

  connection=$(nm_field "$device" GENERAL.CONNECTION)
  if ! wait_for_stable_wifi "${connection:-}"; then
    if [[ "$mode" == "manual" ]]; then
      echo "Wi-Fi connection is still changing; retry in a few seconds." >&2
      notify_portal "Wi-Fi login" "Network is still changing on ${connection:-Wi-Fi}. Retry in a few seconds."
      return 1
    fi
    return 0
  fi

  device=$(active_wifi_device || true)
  [[ -n "$device" ]] || return 1

  connection=$(nm_field "$device" GENERAL.CONNECTION)
  state=$(connectivity_name "$device")
  bssid=$(active_bssid "$device")
  ip4=$(nm_field "$device" IP4.ADDRESS)
  gw=$(nm_field "$device" IP4.GATEWAY)

  if [[ "$mode" == "auto" ]]; then
    case "$state" in
      portal|limited)
        ;;
      *)
        return 0
        ;;
    esac
  fi

  if launch_default_browser; then
    message="Opening ${FALLBACK_URL} for ${connection:-Wi-Fi} (${state})."
  else
    echo "No browser launcher is available" >&2
    notify_portal "Wi-Fi login" "Could not find a browser launcher."
    return 1
  fi

  record_launch "${connection:-}" "${bssid:-}" "${state:-unknown}"

  if [[ "$mode" == "manual" ]]; then
    show_status "$device" "$connection" "$state" "$bssid" "$ip4" "$gw"
  fi

  notify_portal "Wi-Fi login" "$message"
}

maybe_open_portal() {
  local device connection state bssid

  device=$(active_wifi_device || true)
  [[ -n "$device" ]] || return 0

  connection=$(nm_field "$device" GENERAL.CONNECTION)
  state=$(connectivity_name "$device")
  bssid=$(active_bssid "$device")

  case "$state" in
    portal|limited)
      ;;
    *)
      return 0
      ;;
  esac

  if recent_launch_matches "${connection:-}" "${bssid:-}"; then
    return 0
  fi

  open_portal auto || true
}

monitor_portal() {
  mkdir -p "$STATE_DIR"

  exec 9>"$LOCK_FILE"
  flock -n 9 || exit 0

  maybe_open_portal

  while IFS= read -r _line; do
    maybe_open_portal
  done < <(nmcli monitor)
}

command_name=${1:-open}

case "$command_name" in
  open)
    open_portal manual
    ;;
  monitor)
    monitor_portal
    ;;
  status)
    device=$(active_wifi_device || true)
    if [[ -z "$device" ]]; then
      echo "No active Wi-Fi connection found"
      exit 1
    fi
    show_status \
      "$device" \
      "$(nm_field "$device" GENERAL.CONNECTION)" \
      "$(connectivity_name "$device")" \
      "$(active_bssid "$device")" \
      "$(nm_field "$device" IP4.ADDRESS)" \
      "$(nm_field "$device" IP4.GATEWAY)"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $command_name" >&2
    usage >&2
    exit 1
    ;;
esac
