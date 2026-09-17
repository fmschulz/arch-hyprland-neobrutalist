#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TYPE_DIR="$PROJECT_DIR/.types"
RUNTIME_ENV="${AGS_RUNTIME_ENV:-$HOME/.local/share/arch-hypr-neobrutalist/ags/env.sh}"

if [[ ! -f "$RUNTIME_ENV" ]]; then
  printf 'prepare-types.sh: runtime environment not found: %s\n' "$RUNTIME_ENV" >&2
  exit 1
fi

# The environment path is intentionally configurable for isolated runtime tests.
# shellcheck disable=SC1090
source "$RUNTIME_ENV"

if [[ ! -x "$PROJECT_DIR/node_modules/.bin/tsc" ]]; then
  printf 'prepare-types.sh: run npm ci in %s first\n' "$PROJECT_DIR" >&2
  exit 1
fi

mkdir -p "$TYPE_DIR"
find "$TYPE_DIR" -mindepth 1 -delete

ags types 'Astal*' -d "$TYPE_DIR"
ags types 'Adw*' -d "$TYPE_DIR"

mapfile -t sdk_sources < <(
  find "$AGS_JS_PACKAGE/lib" "$AGS_JS_PACKAGE/node_modules/gnim/dist" \
    -type f -name '*.ts' \
    ! -path '*/gtk3/*' \
    ! -path '*/gnome/*' \
    | sort
)

"$PROJECT_DIR/node_modules/.bin/tsc" \
  --declaration \
  --emitDeclarationOnly \
  --noCheck \
  --module ES2022 \
  --moduleResolution Bundler \
  --target ES2020 \
  --rootDir "$AGS_JS_PACKAGE" \
  --outDir "$TYPE_DIR/sdk" \
  "${sdk_sources[@]}"

printf 'Generated AGS, Gnim, and GIR declarations in %s\n' "$TYPE_DIR"
