#!/bin/bash
# Music moved to bester-ytm (uv tool); drop the synced radio artifacts, which
# rsync-based applies never delete on their own.
set -euo pipefail

rm -f "$HOME/.config/scripts/radio.sh" \
  "$HOME/.config/arch-hypr-neobrutalist/radio-stations.tsv" \
  "$HOME/.config/arch-hypr-neobrutalist/radio-stations.tsv.example"
