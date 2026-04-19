#!/bin/bash
# System health report - quick overview of system status
# Run with: health (if alias is set) or ~/.config/scripts/system-health.sh

echo "=== System Health Report $(date +%Y-%m-%d) ==="

echo -e "\n--- Failed Services ---"
FAILED=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
if [ "$FAILED" -gt 0 ]; then
    echo "WARNING: $FAILED failed service(s):"
    systemctl --failed --no-pager
else
    echo "OK: No failed services"
fi

echo -e "\n--- Disk Usage ---"
df -h / /home 2>/dev/null | tail -n+2

echo -e "\n--- Cache Sizes ---"
echo "Pacman: $(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)"
echo "User cache: $(du -sh ~/.cache 2>/dev/null | cut -f1)"

echo -e "\n--- Journal ---"
journalctl --disk-usage 2>/dev/null

echo -e "\n--- Orphan Packages ---"
ORPHANS=$(pacman -Qtdq 2>/dev/null | wc -l)
[ "$ORPHANS" -gt 0 ] && echo "$ORPHANS orphan(s): pacman -Qtdq" || echo "None"

echo -e "\n--- Updates Available ---"
UPDATES=$(checkupdates 2>/dev/null | wc -l)
echo "$UPDATES package(s)"
