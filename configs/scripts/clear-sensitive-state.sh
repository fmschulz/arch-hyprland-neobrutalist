#!/usr/bin/env bash
# Clear local transient state that may contain secrets.

set -euo pipefail

if command -v cliphist >/dev/null 2>&1; then
  cliphist wipe >/dev/null 2>&1 || true
fi

if command -v wl-copy >/dev/null 2>&1; then
  wl-copy --clear >/dev/null 2>&1 || true
  wl-copy --primary --clear >/dev/null 2>&1 || true
fi
