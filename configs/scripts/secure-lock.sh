#!/usr/bin/env bash
# Clear clipboard history before locking the session.

set -euo pipefail

"${XDG_CONFIG_HOME:-$HOME/.config}/scripts/clear-sensitive-state.sh" || true

if pidof hyprlock >/dev/null 2>&1; then
  exit 0
fi

exec hyprlock
