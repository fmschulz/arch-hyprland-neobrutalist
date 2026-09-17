#!/bin/bash
set -euo pipefail

# Recover from the common "Wi-Fi connected, IPv6 works, IPv4 is limited" state.
# Usage:
#   wifi-heal.sh           # reconnect only when IPv4 looks unhealthy
#   wifi-heal.sh --force   # always reconnect the active Wi-Fi connection
#   wifi-heal.sh --status  # print status only

usage() {
    cat <<'EOF'
Usage: wifi-heal.sh [--status] [--force]

Reconnects the active Wi-Fi connection when NetworkManager reports degraded IPv4
connectivity. Useful after roaming or a bad DHCP lease.
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

show_status() {
    local device=$1
    local connection=$2
    local ip4_state=$3
    local ip6_state=$4
    local ip4_addr=$5
    local ip4_gw=$6
    local bssid=$7

    echo "Wi-Fi device: ${device}"
    echo "Connection: ${connection:-<none>}"
    echo "BSSID: ${bssid:-<unknown>}"
    echo "IPv4: ${ip4_state:-<unknown>} (${ip4_addr:-no address}, gw ${ip4_gw:-none})"
    echo "IPv6: ${ip6_state:-<unknown>}"
}

status_only=0
force=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --status)
            status_only=1
            shift
            ;;
        --force)
            force=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if ! command -v nmcli >/dev/null 2>&1; then
    echo "nmcli is not available" >&2
    exit 1
fi

device=$(active_wifi_device || true)
if [[ -z "$device" ]]; then
    echo "No active Wi-Fi connection found" >&2
    exit 1
fi

connection=$(nm_field "$device" GENERAL.CONNECTION)
ip4_state=$(nm_field "$device" GENERAL.IP4-CONNECTIVITY)
ip6_state=$(nm_field "$device" GENERAL.IP6-CONNECTIVITY)
ip4_addr=$(nm_field "$device" IP4.ADDRESS)
ip4_gw=$(nm_field "$device" IP4.GATEWAY)
bssid=$(iw dev "$device" link 2>/dev/null | sed -n 's/Connected to //p' | awk '{print $1}')

show_status "$device" "$connection" "$ip4_state" "$ip6_state" "$ip4_addr" "$ip4_gw" "$bssid"

if (( status_only )); then
    exit 0
fi

needs_reconnect=0
if [[ "$ip4_state" != 4* ]] || [[ -z "$ip4_gw" ]]; then
    needs_reconnect=1
fi

if (( ! force && ! needs_reconnect )); then
    echo "Wi-Fi looks healthy; no reconnect needed."
    exit 0
fi

if [[ -z "$connection" || "$connection" == "--" ]]; then
    echo "Cannot reconnect because the active connection name is unavailable" >&2
    exit 1
fi

echo "Reconnecting Wi-Fi connection '${connection}'..."
nmcli connection down "$connection" >/dev/null
sleep 2
nmcli connection up "$connection" >/dev/null
sleep 2

ip4_state=$(nm_field "$device" GENERAL.IP4-CONNECTIVITY)
ip6_state=$(nm_field "$device" GENERAL.IP6-CONNECTIVITY)
ip4_addr=$(nm_field "$device" IP4.ADDRESS)
ip4_gw=$(nm_field "$device" IP4.GATEWAY)
bssid=$(iw dev "$device" link 2>/dev/null | sed -n 's/Connected to //p' | awk '{print $1}')

echo
show_status "$device" "$connection" "$ip4_state" "$ip6_state" "$ip4_addr" "$ip4_gw" "$bssid"

if [[ "$ip4_state" == 4* ]] && [[ -n "$ip4_gw" ]]; then
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Wi-Fi" "Recovered IPv4 connectivity on ${connection}" -t 2500
    fi
    echo "Recovery complete."
    exit 0
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send "Wi-Fi" "IPv4 is still degraded on ${connection}" -t 3500
fi
echo "IPv4 is still degraded after reconnect." >&2
exit 1
