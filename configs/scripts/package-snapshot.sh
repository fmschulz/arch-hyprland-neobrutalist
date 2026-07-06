#!/bin/bash
# Report drift between installed packages and the curated repo manifests
# (packages/pacman.txt, pacman-amd.txt, aur.txt). Read-only: the manifests
# are curated by hand, so this prints the diff instead of overwriting them.
# Run from a repo checkout, or set PACKAGES_DIR explicitly.

set -euo pipefail

# Script lives in configs/scripts/ inside the repo, so the manifests are two
# levels up. The synced copy in ~/.config/scripts has no repo around it —
# run it from the checkout or point PACKAGES_DIR at one.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="${PACKAGES_DIR:-$SCRIPT_DIR/../../packages}"

if [[ ! -f "$PACKAGES_DIR/pacman.txt" ]]; then
    echo "Manifests not found at $PACKAGES_DIR (run from the repo checkout or set PACKAGES_DIR)" >&2
    exit 1
fi

manifest_pkgs() {
    sed -E 's/[[:space:]]*#.*$//' "$@" | sed '/^[[:space:]]*$/d' | sort -u
}

repo_manifests=("$PACKAGES_DIR/pacman.txt")
[[ -f "$PACKAGES_DIR/pacman-amd.txt" ]] && repo_manifests+=("$PACKAGES_DIR/pacman-amd.txt")

echo "=== Package drift vs manifests in $PACKAGES_DIR ==="

echo
echo "-- Repo packages installed explicitly but not in pacman*.txt --"
comm -23 <(pacman -Qeqn | sort -u) <(manifest_pkgs "${repo_manifests[@]}") | sed 's/^/  + /'

echo
echo "-- Repo packages in pacman*.txt but not installed --"
comm -13 <(pacman -Qqn | sort -u) <(manifest_pkgs "${repo_manifests[@]}") | sed 's/^/  - /'

echo
echo "-- Foreign (AUR) packages installed explicitly but not in aur.txt --"
comm -23 <(pacman -Qeqm | sort -u) <(manifest_pkgs "$PACKAGES_DIR/aur.txt") | sed 's/^/  + /'

echo
echo "-- Foreign (AUR) packages in aur.txt but not installed --"
comm -13 <(pacman -Qqm | sort -u) <(manifest_pkgs "$PACKAGES_DIR/aur.txt") | sed 's/^/  - /'

echo
echo "Edit packages/*.txt by hand to adopt or drop entries."
