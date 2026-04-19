#!/bin/bash
# Auto-switch power profile based on AC/battery status
# Called by udev rule on power supply change

# Try different power supply names (Framework uses ACAD, some systems use AC)
AC_ONLINE=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || \
            cat /sys/class/power_supply/AC/online 2>/dev/null || \
            echo "1")

if [ "$AC_ONLINE" = "1" ]; then
    powerprofilesctl set balanced
else
    powerprofilesctl set power-saver
fi
