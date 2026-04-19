#!/bin/bash
set -euo pipefail

# Show Wi-Fi networks sorted by signal strength and connect via nmcli.

menu_cmd=(wofi --dmenu --prompt "Wi-Fi" --width 560 --height 400 --matching fuzzy --allow-markup)

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
  [[ "$sec_label" == "--" ]] && sec_label="open"

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

[[ -z "$choice_ssid" ]] && exit 0

if nmcli -g NAME connection show | grep -Fxq "$choice_ssid"; then
  nmcli connection up "$choice_ssid"
else
  if [[ "$choice_security" == "open" ]]; then
    nmcli device wifi connect "$choice_ssid"
  else
    nmcli --ask device wifi connect "$choice_ssid"
  fi
fi
