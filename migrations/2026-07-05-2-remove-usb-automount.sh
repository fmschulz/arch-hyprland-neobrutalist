#!/bin/bash
# The udev USB automounter could never publish its mounts (systemd-udevd runs
# with private mounts); udiskie owns automounting. Remove installed artifacts.
set -euo pipefail

rule=/etc/udev/rules.d/99-arch-hypr-neobrutalist-usb-automount.rules
handler=/usr/local/lib/arch-hypr-neobrutalist/usb-automount.sh
conf=/etc/arch-hypr-neobrutalist/usb-automount.conf

[[ -e "$rule" || -e "$handler" || -e "$conf" ]] || exit 0

# Needs root; failing here leaves the migration pending so it retries on the
# next apply from an interactive terminal.
sudo rm -f "$rule" "$handler" "$conf"
sudo rmdir /usr/local/lib/arch-hypr-neobrutalist /etc/arch-hypr-neobrutalist 2>/dev/null || true
sudo udevadm control --reload 2>/dev/null || true
