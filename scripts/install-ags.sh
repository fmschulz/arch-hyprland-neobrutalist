#!/usr/bin/env bash
# Build the pinned AGS 3 runtime without installing system packages.

set -euo pipefail

RUNTIME_ENV="${AGS_RUNTIME_ENV:-$HOME/.local/share/arch-hypr-neobrutalist/ags/env.sh}"
INSTALL_ROOT="$(dirname "$RUNTIME_ENV")"
WORK_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/arch-hypr-neobrutalist/ags-runtime"
DOWNLOAD_DIR="$WORK_ROOT/downloads"
ARCH_ROOT="$INSTALL_ROOT/arch"
PREFIX="$INSTALL_ROOT/prefix"

ASTAL_COMMIT="ae8dc0acc66932171ec70d347a8cab9310ce74e4"
CACHE_KEY="ags-3.1.2-astal-${ASTAL_COMMIT:0:12}-appmenu-25.04-r2"
SOURCE_DIR="$WORK_ROOT/$CACHE_KEY/sources"
BUILD_DIR="$WORK_ROOT/$CACHE_KEY/build"

step() {
  printf '==> %s\n' "$1"
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'install-ags.sh: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

runtime_complete() {
  [[ -f "$INSTALL_ROOT/.complete" \
    && -f "$RUNTIME_ENV" \
    && -x "$PREFIX/bin/ags" \
    && -d "$PREFIX/share/ags/js" ]] \
    && grep -Fxq 'AGS 3.1.2 installation in progress' "$INSTALL_ROOT/.complete"
}

fetch() {
  local url="$1"
  local destination="$2"
  local checksum="$3"

  if [[ -f "$destination" ]] \
    && printf '%s  %s\n' "$checksum" "$destination" | sha256sum --check --status; then
    return
  fi

  curl --fail --location --retry 3 --output "$destination.tmp" "$url"
  printf '%s  %s\n' "$checksum" "$destination.tmp" | sha256sum --check --status
  mv "$destination.tmp" "$destination"
}

fetch_arch_package() {
  local name="$1"
  local url="$2"
  local checksum="$3"
  local package="$DOWNLOAD_DIR/$name.pkg.tar.zst"

  fetch "$url" "$package" "$checksum"
  if [[ ! -f "$package.sig" ]] \
    || ! pacman-key --verify "$package.sig" "$package" >/dev/null 2>&1; then
    curl --fail --location --retry 3 --output "$package.sig.tmp" "$url.sig"
    mv "$package.sig.tmp" "$package.sig"
  fi
  pacman-key --verify "$package.sig" "$package"
  bsdtar --extract --file "$package" --directory "$ARCH_ROOT"
}

build_meson() {
  local name="$1"
  local source="$2"
  local reconfigure=()
  shift 2

  if [[ -f "$BUILD_DIR/$name/meson-private/coredata.dat" ]]; then
    reconfigure=(--reconfigure)
  fi

  meson setup "${reconfigure[@]}" "$BUILD_DIR/$name" "$source" \
    --prefix="$PREFIX" --libdir=lib "$@"
  meson compile -C "$BUILD_DIR/$name"
  meson install -C "$BUILD_DIR/$name"
}

if runtime_complete; then
  step "AGS runtime is already installed: $INSTALL_ROOT"
  exit 0
fi

for command in bsdtar curl gcc g-ir-compiler go meson ninja pacman-key \
  pkg-config python3 sed sha256sum; do
  need "$command"
done

step "Preparing isolated build and install directories"
if [[ -e "$INSTALL_ROOT" && ! -f "$INSTALL_ROOT/.installing" ]]; then
  printf 'install-ags.sh: refusing to replace incomplete path: %s\n' "$INSTALL_ROOT" >&2
  exit 1
fi
mkdir -p "$DOWNLOAD_DIR" "$SOURCE_DIR" "$BUILD_DIR" "$INSTALL_ROOT"
printf 'AGS 3.1.2 installation in progress\n' >"$INSTALL_ROOT/.installing"
mkdir -p "$ARCH_ROOT" "$PREFIX"

step "Downloading and verifying Arch build/runtime packages"
fetch_arch_package \
  js140 \
  "https://archive.archlinux.org/packages/j/js140/js140-140.14.0-1-x86_64.pkg.tar.zst" \
  "d4525f09cb8363851acdd7cb8ad09cd1de936d7872fb9520d4ee09a3e4b1688f"
fetch_arch_package \
  gjs \
  "https://archive.archlinux.org/packages/g/gjs/gjs-2:1.88.1-1-x86_64.pkg.tar.zst" \
  "b95ba83a89d29b7d3a403a2f5052c778d95cf9358d3e5eed9e633cf20fb75926"
fetch_arch_package \
  vala \
  "https://archive.archlinux.org/packages/v/vala/vala-0.56.19-2-x86_64.pkg.tar.zst" \
  "b9c8a82c6ea2c2a61d0f85e0de23ed1cd2b01aa0e52e459ab9fe879ca39921e4"
# Astal generates its GIR files with Valadoc, whose library links to Graphviz.
fetch_arch_package \
  graphviz \
  "https://archive.archlinux.org/packages/g/graphviz/graphviz-16.0.0-1-x86_64.pkg.tar.zst" \
  "b705040d17cb094adcc48d47e034fd42d6b2108cd78cd0bfc60f2e4c727d28e4"
fetch_arch_package \
  glib2-devel \
  "https://archive.archlinux.org/packages/g/glib2-devel/glib2-devel-2.88.3-1-x86_64.pkg.tar.zst" \
  "07c1434a09e2267377bce44ce52a2c280175cc0bce4c5b5ef8c728255e8f49f0"

step "Downloading and verifying pinned source archives"
fetch \
  "https://github.com/Aylur/ags/releases/download/v3.1.2/ags-v3.1.2.tar.gz" \
  "$DOWNLOAD_DIR/ags-v3.1.2.tar.gz" \
  "cefed61736acdd0d15fcc191191309d1072dbfb0fe0062b43e5d9730b5408297"
fetch \
  "https://codeload.github.com/Aylur/astal/tar.gz/$ASTAL_COMMIT" \
  "$DOWNLOAD_DIR/astal-$ASTAL_COMMIT.tar.gz" \
  "a5ea9a71819cc3113fad47756b753b8db25d11ad22eaca1d53088ea619058925"
fetch \
  "https://gitlab.com/vala-panel-project/vala-panel-appmenu/-/archive/25.04/vala-panel-appmenu-25.04.tar.gz" \
  "$DOWNLOAD_DIR/vala-panel-appmenu-25.04.tar.gz" \
  "48d0be87b260056a65a9056a9be7e190b67a508540ebcb1fc18a67349cca0177"

tar -xzf "$DOWNLOAD_DIR/ags-v3.1.2.tar.gz" -C "$SOURCE_DIR"
tar -xzf "$DOWNLOAD_DIR/astal-$ASTAL_COMMIT.tar.gz" -C "$SOURCE_DIR"
tar -xzf "$DOWNLOAD_DIR/vala-panel-appmenu-25.04.tar.gz" -C "$SOURCE_DIR"

export PATH="$ARCH_ROOT/usr/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$ARCH_ROOT/usr/lib:$ARCH_ROOT/usr/lib/vala-0.56${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
GLIB_PC="$(pkg-config --path glib-2.0)"
GIO_PC="$(pkg-config --path gio-2.0)"
sed \
  -e "s|^glib_genmarshal=.*|glib_genmarshal=$ARCH_ROOT/usr/bin/glib-genmarshal|" \
  -e "s|^glib_mkenums=.*|glib_mkenums=$ARCH_ROOT/usr/bin/glib-mkenums|" \
  "$GLIB_PC" >"$BUILD_DIR/glib-2.0.pc"
sed \
  -e "s|^gdbus_codegen=.*|gdbus_codegen=$ARCH_ROOT/usr/bin/gdbus-codegen|" \
  "$GIO_PC" >"$BUILD_DIR/gio-2.0.pc"
mkdir -p "$BUILD_DIR/bin"
cat >"$BUILD_DIR/bin/valadoc" <<EOF
#!/bin/sh
exec "$ARCH_ROOT/usr/bin/valadoc" \
  --doclet "$ARCH_ROOT/usr/lib/valadoc-0.56/doclets/html" "\$@"
EOF
chmod +x "$BUILD_DIR/bin/valadoc"
export PKG_CONFIG_PATH="$BUILD_DIR:$PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export GI_TYPELIB_PATH="$PREFIX/lib/girepository-1.0:$ARCH_ROOT/usr/lib/gjs/girepository-1.0${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
export XDG_DATA_DIRS="$PREFIX/share:$ARCH_ROOT/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export VALAFLAGS="--vapidir=$PREFIX/share/vala/vapi --vapidir=$ARCH_ROOT/usr/share/vala/vapi --vapidir=$ARCH_ROOT/usr/share/vala-0.56/vapi"
export VALADOC="$BUILD_DIR/bin/valadoc"

ASTAL_SOURCE="$SOURCE_DIR/astal-$ASTAL_COMMIT"

step "Building native Astal libraries"
build_meson appmenu-glib-translator \
  "$SOURCE_DIR/vala-panel-appmenu-25.04/subprojects/appmenu-glib-translator"
build_meson astal-io "$ASTAL_SOURCE/lib/astal/io"
mkdir -p "$PREFIX/include/astal-io"
ln -sfn ../astal-io.h "$PREFIX/include/astal-io/astal-io.h"
build_meson astal-gtk4 "$ASTAL_SOURCE/lib/astal/gtk4"
build_meson astal-hyprland "$ASTAL_SOURCE/lib/hyprland" -Dcli=false
build_meson astal-mpris "$ASTAL_SOURCE/lib/mpris" -Dcli=false
build_meson astal-network "$ASTAL_SOURCE/lib/network"
build_meson astal-tray "$ASTAL_SOURCE/lib/tray" -Dcli=false
build_meson astal-wireplumber "$ASTAL_SOURCE/lib/wireplumber"

step "Building AGS 3.1.2"
build_meson ags "$SOURCE_DIR/ags"

cat >"$RUNTIME_ENV" <<EOF
# Generated by scripts/install-ags.sh.
export AGS_RUNTIME_ROOT="$INSTALL_ROOT"
export AGS_PREFIX="\$AGS_RUNTIME_ROOT/prefix"
export AGS_JS_PACKAGE="\$AGS_PREFIX/share/ags/js"
export PATH="\$AGS_PREFIX/bin:\$AGS_RUNTIME_ROOT/arch/usr/bin\${PATH:+:\$PATH}"
export LD_LIBRARY_PATH="\$AGS_PREFIX/lib:\$AGS_RUNTIME_ROOT/arch/usr/lib:\$AGS_RUNTIME_ROOT/arch/usr/lib/vala-0.56\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
export GI_TYPELIB_PATH="\$AGS_PREFIX/lib/girepository-1.0:\$AGS_RUNTIME_ROOT/arch/usr/lib/gjs/girepository-1.0\${GI_TYPELIB_PATH:+:\$GI_TYPELIB_PATH}"
export EXTRA_GIR_DIRS="\$AGS_PREFIX/share/gir-1.0\${EXTRA_GIR_DIRS:+:\$EXTRA_GIR_DIRS}"
export XDG_DATA_DIRS="\$AGS_PREFIX/share:\$AGS_RUNTIME_ROOT/arch/usr/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
EOF

step "Installed runtime environment: $RUNTIME_ENV"
mv "$INSTALL_ROOT/.installing" "$INSTALL_ROOT/.complete"
