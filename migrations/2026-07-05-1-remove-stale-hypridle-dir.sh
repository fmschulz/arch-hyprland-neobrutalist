#!/bin/bash
# hypridle only reads ~/.config/hypr/hypridle.conf; installs made before the
# config moved left a dead copy in ~/.config/hypridle/.
set -euo pipefail

if [[ -f "$HOME/.config/hypr/hypridle.conf" && -d "$HOME/.config/hypridle" ]]; then
  rm -rf "$HOME/.config/hypridle"
fi
