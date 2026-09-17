#!/usr/bin/env bash
set -euo pipefail

runtime_dir=${XDG_RUNTIME_DIR:-}
if [[ -z "$runtime_dir" || ! -d "$runtime_dir" || ! -O "$runtime_dir" || ! -w "$runtime_dir" ]]; then
  exit 0
fi

export SESSION_DIRS=/usr/share/wayland-sessions
export XDG_DATA_DIRS=/usr/share/wayland-sessions:/usr/share

exec /usr/bin/cage -s -- \
  /usr/bin/regreet \
  --config /etc/greetd/regreet.toml \
  --style /etc/greetd/regreet.css
