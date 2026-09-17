#!/bin/bash
# Auto-switch power profile based on AC/battery status
# Called by udev rule on power supply change

# Try common power-supply names.
AC_ONLINE=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || \
            cat /sys/class/power_supply/AC/online 2>/dev/null || \
            echo "1")

if [ "$AC_ONLINE" = "1" ]; then
    powerprofilesctl set performance 2>/dev/null || powerprofilesctl set balanced
else
    powerprofilesctl set power-saver 2>/dev/null || powerprofilesctl set balanced
fi
