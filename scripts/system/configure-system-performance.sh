#!/bin/bash
# Configure system performance and maintenance settings
# Run with sudo: sudo bash configure-system-performance.sh [USERNAME]

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo)." >&2
    exit 1
fi

TARGET_USER="${1:-${SUDO_USER:-$(logname)}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

if [[ -z "$TARGET_HOME" ]]; then
    echo "Could not determine home directory for user: ${TARGET_USER}" >&2
    exit 1
fi

echo -e "${GREEN}Configuring system for user: ${TARGET_USER}${NC}"

# =============================================================================
# Memory/Swap Optimization (for high-RAM systems)
# =============================================================================
print_step "Configuring memory optimization (sysctl)"

mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-arch-performance.conf << 'EOF'
# Performance tuning for high-RAM systems
# Reduce swappiness - with lots of RAM, prefer keeping data in memory
vm.swappiness=10

# Reduce cache pressure - keep more filesystem cache
vm.vfs_cache_pressure=50

# Write data to disk more frequently (reduces data loss risk)
vm.dirty_ratio=10
vm.dirty_background_ratio=5
EOF

sysctl --system > /dev/null
echo -e "${GREEN}✓ Memory optimization configured${NC}"

# =============================================================================
# Journal Size Limits
# =============================================================================
print_step "Configuring journal size limits"

mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/size.conf << 'EOF'
[Journal]
SystemMaxUse=500M
SystemMaxFileSize=50M
MaxRetentionSec=1month
EOF

systemctl restart systemd-journald
echo -e "${GREEN}✓ Journal limits configured (max 500MB)${NC}"

# =============================================================================
# Pacman Cache Cleanup Timer
# =============================================================================
print_step "Setting up pacman cache cleanup timer"

# Ensure pacman-contrib is installed (provides paccache)
if ! pacman -Qi pacman-contrib &>/dev/null; then
    echo -e "${YELLOW}Installing pacman-contrib...${NC}"
    pacman -S --needed --noconfirm pacman-contrib
fi

cat > /etc/systemd/system/paccache.service << 'EOF'
[Unit]
Description=Clean pacman package cache

[Service]
Type=oneshot
ExecStart=/usr/bin/paccache -rk2
ExecStart=/usr/bin/paccache -ruk0
EOF

cat > /etc/systemd/system/paccache.timer << 'EOF'
[Unit]
Description=Clean pacman cache weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now paccache.timer
echo -e "${GREEN}✓ Pacman cache cleanup timer enabled (weekly)${NC}"

# =============================================================================
# Power Profile Auto-Switching (for laptops)
# =============================================================================
print_step "Configuring automatic power profile switching"

POWER_SCRIPT="${TARGET_HOME}/.config/scripts/auto-power-profile.sh"

if [[ -f "$POWER_SCRIPT" ]]; then
    cat > /etc/udev/rules.d/99-power-profile-switch.rules << EOF
# Auto-switch power profile on AC/battery change
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="${POWER_SCRIPT}"
EOF
    udevadm control --reload-rules
    echo -e "${GREEN}✓ Power profile auto-switching configured${NC}"
else
    echo -e "${YELLOW}⚠ Power profile script not found at ${POWER_SCRIPT}, skipping udev rule${NC}"
fi

# =============================================================================
# Summary
# =============================================================================
echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         System Performance Configuration Complete            ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC} ✓ Memory: swappiness=10, vfs_cache_pressure=50              ${GREEN}║${NC}"
echo -e "${GREEN}║${NC} ✓ Journal: max 500MB, 1 month retention                     ${GREEN}║${NC}"
echo -e "${GREEN}║${NC} ✓ Paccache: weekly cleanup, keeps 2 versions                ${GREEN}║${NC}"
echo -e "${GREEN}║${NC} ✓ Power: auto power-saver on battery (if script exists)     ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
