#!/bin/bash
set -euo pipefail

# Open a calendar UI when called from Waybar.
# Tries gsimplecal (lightweight), then GNOME/KDE calendars, otherwise notifies.

launch() {
  nohup "$@" >/dev/null 2>&1 &
}

if command -v gsimplecal >/dev/null 2>&1; then
  launch gsimplecal
elif command -v gnome-calendar >/dev/null 2>&1; then
  launch gnome-calendar
elif command -v kalendar >/dev/null 2>&1; then
  launch kalendar
elif command -v korganizer >/dev/null 2>&1; then
  launch korganizer
else
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Calendar not installed" "Install gsimplecal or gnome-calendar to enable click action."
  fi
fi
