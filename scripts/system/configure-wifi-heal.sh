#!/bin/bash
# Install a post-suspend WiFi self-heal: the MediaTek MT7922 (mt7921e) can come
# out of s2idle in a state where scans half-work but authentication loops with
# CONN_FAILED for minutes. This unit waits after resume and reloads the module
# only if the link has not come back on its own.
# Run with sudo: sudo bash configure-wifi-heal.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (sudo)." >&2
  exit 1
fi

HEAL_SCRIPT=/usr/local/lib/wifi-resume-heal.sh
UNIT=/etc/systemd/system/wifi-resume-heal.service

install -d /usr/local/lib

cat >"$HEAL_SCRIPT" <<'EOF'
#!/bin/bash
# Post-resume WiFi self-heal for mt7921e. Give NetworkManager a fair chance
# to reconnect on its own; reload the module only as a last resort.
set -u

# Only act when the mt7921e module drives an interface.
dev=""
for d in /sys/class/net/*/device/driver; do
  if [[ "$(readlink -f "$d" 2>/dev/null)" == *mt7921e* ]]; then
    dev="$(basename "$(dirname "$(dirname "$d")")")"
    break
  fi
done
[[ -z "$dev" ]] && exit 0

# Respect an intentionally disabled radio.
if command -v nmcli >/dev/null 2>&1; then
  [[ "$(nmcli radio wifi 2>/dev/null)" == "disabled" ]] && exit 0
fi

# Up to 60 s of patience: NM usually reassociates within seconds.
for _ in $(seq 1 6); do
  sleep 10
  state="$(nmcli -t -f DEVICE,STATE device 2>/dev/null | grep "^${dev}:" | cut -d: -f2)"
  if [[ "$state" == "connected" ]]; then
    exit 0
  fi
done

logger -t wifi-resume-heal "$dev still ${state:-unknown} 60s after resume; reloading mt7921e"
modprobe -r mt7921e && sleep 2 && modprobe mt7921e
EOF
chmod 755 "$HEAL_SCRIPT"

cat >"$UNIT" <<EOF
[Unit]
Description=Reload mt7921e if WiFi fails to reassociate after resume
After=suspend.target

[Service]
Type=oneshot
ExecStart=$HEAL_SCRIPT

[Install]
WantedBy=suspend.target
EOF

systemctl daemon-reload
systemctl enable wifi-resume-heal.service

echo "Installed and enabled wifi-resume-heal.service (fires after every resume)."
