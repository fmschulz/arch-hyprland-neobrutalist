#!/bin/bash

# Welcome script for Arch Linux Hyprland setup
# Neo-brutalist themed welcome message
# Shows every time a new terminal opens

# Only run in interactive shells, once per session (guards against a shell
# config that sources the chain twice).
[[ $- != *i* ]] && return
[[ -n ${WELCOME_SHOWN:-} ]] && return
export WELCOME_SHOWN=1

# Show system info with fastfetch (compact)
if command -v fastfetch >/dev/null 2>&1; then
  fastfetch --logo arch_small --structure Title:OS:Kernel:Uptime:Shell:WM:Terminal:CPU:Memory
  echo
fi

# Local weather + 5-day forecast (optional, °C). Location is machine-local: set
# WEATHER_LAT/WEATHER_LON (and optionally WEATHER_TZ/WEATHER_CITY) in
# ~/.config/arch-hypr-neobrutalist/welcome.conf (see welcome.conf.example).
# Skipped entirely when no coordinates are configured.
weather_conf="${XDG_CONFIG_HOME:-$HOME/.config}/arch-hypr-neobrutalist/welcome.conf"
# shellcheck source=/dev/null
[[ -f "$weather_conf" ]] && source "$weather_conf"
if [[ -n "${WEATHER_LAT:-}" && -n "${WEATHER_LON:-}" ]] && command -v curl >/dev/null 2>&1 && command -v python >/dev/null 2>&1; then
  # Cache the forecast for 15 min so opening a terminal doesn't block up to
  # 2s per tab on a slow network; fall back to the last snapshot offline.
  weather_cache="${XDG_CACHE_HOME:-$HOME/.cache}/arch-hypr-neobrutalist-weather.json"
  weather_json=""
  if [[ -f "$weather_cache" ]] && (($(date +%s) - $(stat -c %Y "$weather_cache" 2>/dev/null || echo 0) < 900)); then
    weather_json="$(<"$weather_cache")"
  else
    weather_json="$(curl -s --max-time 2 \
      "https://api.open-meteo.com/v1/forecast?latitude=${WEATHER_LAT}&longitude=${WEATHER_LON}&current_weather=true&daily=weathercode,temperature_2m_max,temperature_2m_min&forecast_days=5&timezone=${WEATHER_TZ:-auto}")"
    if [[ -n "$weather_json" ]]; then
      printf '%s' "$weather_json" >"$weather_cache"
    elif [[ -f "$weather_cache" ]]; then
      weather_json="$(<"$weather_cache")"
    fi
  fi
  python - <<'PY' "$weather_json" "${WEATHER_CITY:-Local}"
import json
import sys
from datetime import datetime

data = json.loads(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1] else {}
city = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else "Local"
current = data.get("current_weather") or {}
daily = data.get("daily") or {}

code_map = {
    0: "☀️",
    1: "🌤️",
    2: "⛅",
    3: "☁️",
    45: "🌫️",
    48: "🌫️",
    51: "🌦️",
    53: "🌦️",
    55: "🌧️",
    56: "🌧️",
    57: "🌧️",
    61: "🌧️",
    63: "🌧️",
    65: "🌧️",
    66: "🌧️",
    67: "🌧️",
    71: "🌨️",
    73: "🌨️",
    75: "🌨️",
    77: "🌨️",
    80: "🌧️",
    81: "🌧️",
    82: "🌧️",
    85: "🌨️",
    86: "🌨️",
    95: "⛈️",
    96: "⛈️",
    99: "⛈️",
}

def sym(code):
    return code_map.get(code, "❓")

temp = current.get("temperature")
code = current.get("weathercode")
if temp is not None and code is not None:
    print(f"{city}: now {sym(code)} {round(temp)}°C")

times = daily.get("time") or []
codes = daily.get("weathercode") or []
tmax = daily.get("temperature_2m_max") or []
tmin = daily.get("temperature_2m_min") or []

if times and codes and tmax and tmin:
    line = "5-day:"
    for t, c, hi, lo in zip(times, codes, tmax, tmin):
        try:
            day = datetime.fromisoformat(t).strftime("%a")
        except ValueError:
            day = t
        line += f" {day} {sym(c)} {round(hi)}/{round(lo)}°C"
    print(line)
PY
  echo
fi

# Keybindings are not listed here: Super+/ opens the searchable cheatsheet.
