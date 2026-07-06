#!/usr/bin/env bash
set -euo pipefail

kitty --detach --class calendar-popup --title Calendar ~/.config/scripts/calendar-tui.sh "$@"
