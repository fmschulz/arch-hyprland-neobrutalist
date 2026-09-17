#!/bin/bash
set -euo pipefail

# Use the GTK form while the explicit AGS trial is running.
ags_shell="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/ags-shell.sh"
if [[ -x "$ags_shell" ]] && [[ "$("$ags_shell" status 2>/dev/null || true)" == running ]]; then
  exec "$ags_shell" toggle network
fi

# Show Wi-Fi networks sorted by signal strength and connect via nmcli.

# Single instance: a second click while this one is prompting or connecting
# would start a competing activation that aborts the first (seen as "could
# not connect" while the device was in fact connecting).
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/wifi-menu.lock"
if ! flock -n 9; then
  notify-send "Waybar Wi-Fi" "Wi-Fi menu is already open or still connecting"
  exit 0
fi

# Waybar discards a click handler's output, so a failure here is invisible.
# Trace the run to a file, keeping one previous run for comparison.
log="${XDG_RUNTIME_DIR:-/tmp}/wifi-menu.log"
[[ -f "$log" ]] && mv -f "$log" "$log.prev"
exec 2>"$log"
set -x

menu_cmd=(wofi --dmenu --prompt "Wi-Fi" --width 560 --height 510 --matching fuzzy --allow-markup)

if ! command -v nmcli >/dev/null 2>&1; then
  notify-send "Waybar Wi-Fi" "nmcli not available"
  exit 1
fi

nmcli device wifi rescan >/dev/null 2>&1 || true

mapfile -t wifi_rows < <(nmcli -t -f ACTIVE,SSID,SECURITY,SIGNAL dev wifi list | sort -t: -k4 -nr)

declare -a labels=()
declare -a ssids=()
declare -a securities=()
declare -A seen_ssid=()

for row in "${wifi_rows[@]}"; do
  IFS=: read -r active ssid security signal <<<"$row"
  [[ -z "$ssid" ]] && continue
  if [[ -n "${seen_ssid[$ssid]:-}" ]]; then
    continue
  fi
  seen_ssid["$ssid"]=1

  mark="  "
  [[ "$active" == "yes" ]] && mark="* "

  sec_label="$security"
  # nmcli -t prints an EMPTY security field for open networks ("--" only in table mode).
  [[ -z "$sec_label" || "$sec_label" == "--" ]] && sec_label="open"

  signal_display="${signal:-0}"
  label=$(printf "%s%-40s %3s%%  [%s]" "$mark" "$ssid" "$signal_display" "$sec_label")

  labels+=("$label")
  ssids+=("$ssid")
  securities+=("$sec_label")
done

if [[ ${#labels[@]} -eq 0 ]]; then
  notify-send "Waybar Wi-Fi" "No networks found"
  exit 0
fi

selected="$(printf '%s\n' "${labels[@]}" | "${menu_cmd[@]}")"
[[ -z "$selected" ]] && exit 0

choice_ssid=""
choice_security="open"
for i in "${!labels[@]}"; do
  if [[ "${labels[$i]}" == "$selected" ]]; then
    choice_ssid="${ssids[$i]}"
    choice_security="${securities[$i]}"
    break
  fi
done

if [[ -z "$choice_ssid" ]]; then
  notify-send "Waybar Wi-Fi" "Could not match the selected row to a network"
  exit 1
fi

# `set -e` aborts the script silently when a connect fails (wrong password,
# out of range), so route nmcli through this and let the caller decide.
connect_err=""
try_connect() {
  if connect_err="$("$@" 2>&1)"; then
    return 0
  fi
  return 1
}

# Another activation (NM autoconnect, a stray second request) can abort our
# nmcli call even though the device ends up connected; check before failing.
fail_notify() {
  local i
  for i in 1 2 3; do
    grep -Fxq "$choice_ssid" <<<"$(nmcli -t -f NAME connection show --active)" && return 0
    sleep 2
  done
  notify-send "Waybar Wi-Fi" "Could not connect to $choice_ssid"$'\n'"${connect_err#Error: }"
  exit 1
}

# No TTY under waybar, so `nmcli --ask` could never prompt; ask via wofi.
# Tracing stays off from here on: set -x would otherwise write the
# passphrase into the log in plaintext.
ask_password() {
  set +x
  echo "+ prompting for password for $choice_ssid" >&2
  # wofi's --prompt is GTK placeholder text, hidden as soon as the field has
  # focus, so the box looks like a bare search field. Label it via mako.
  notify-send -u critical -t 20000 "Password for $choice_ssid" \
    "Type it in the box, press Enter"
  if ! password="$(printf '' | wofi --dmenu --password --prompt "Password for $choice_ssid" \
    --width 560 --height 60 --lines 1 --cache-file /dev/null)"; then
    notify-send "Waybar Wi-Fi" "Password prompt failed for $choice_ssid"
    exit 1
  fi
  if [[ -z "$password" ]]; then
    echo "+ empty password returned; nothing to do" >&2
    notify-send "Waybar Wi-Fi" "No password entered; $choice_ssid not connected"
    exit 0
  fi
  echo "+ got a ${#password}-char passphrase for $choice_ssid" >&2
}

# Capture first: piping into grep -q under pipefail can report failure on a
# real match (grep exits early, nmcli gets SIGPIPE).
saved_names="$(nmcli -g NAME connection show)"
if grep -Fxq "$choice_ssid" <<<"$saved_names"; then
  if ! try_connect nmcli connection up "$choice_ssid"; then
    # Phone hotspots regenerate their password, so the saved PSK goes stale
    # and NM fails asking for secrets it cannot get. Re-ask instead of dying.
    if [[ "$connect_err" == *"ecrets were required"* ]]; then
      notify-send "Waybar Wi-Fi" "Saved password for $choice_ssid was rejected - asking again"
      ask_password
      try_connect nmcli connection modify "$choice_ssid" \
        802-11-wireless-security.psk "$password" || fail_notify
      try_connect nmcli connection up "$choice_ssid" || fail_notify
    else
      fail_notify
    fi
  fi
else
  if [[ "$choice_security" == "open" ]]; then
    try_connect nmcli device wifi connect "$choice_ssid" || fail_notify
  else
    ask_password
    try_connect nmcli device wifi connect "$choice_ssid" password "$password" || fail_notify
  fi
fi

notify-send "Waybar Wi-Fi" "Connected to $choice_ssid"

for _ in {1..6}; do
  sleep 2
  connectivity_state="$(nmcli networking connectivity 2>/dev/null || true)"
  case "$connectivity_state" in
    portal|limited)
      ~/.config/scripts/wifi-portal.sh open >/dev/null 2>&1 || true
      break
      ;;
    full)
      break
      ;;
  esac
done
