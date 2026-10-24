#!/usr/bin/env bash
# Convert a rootful deb into a roothide (jbroot-relocatable) deb.
# Works with the standard roothide bootstrap, whose dpkg relocates every
# path under jbroot/ at install time.
#
# Usage: bash scripts/make_roothide.sh <input.deb> <output.deb>
set -euxo pipefail

SRC="${1:?usage: make_roothide.sh <input.deb> <output.deb>}"
OUT="${2:?usage: make_roothide.sh <input.deb> <output.deb>}"

echo "===== input deb info ====="
dpkg-deb -I "$SRC"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# dpkg-deb understands every compression variant (gz / xz / zst) natively,
# so no ar/tar gymnastics are needed.
echo "===== extracting ====="
dpkg-deb -R "$SRC" "$WORK/root"

echo "===== relocating data under jbroot/ ====="
cd "$WORK/root"
mkdir -p jbroot
find . -mindepth 1 -maxdepth 1 ! -name DEBIAN ! -name jbroot -exec mv {} jbroot/ \;

echo "===== repacking ====="
dpkg-deb --root-owner-group -b "$WORK/root" "$OUT"

echo "===== result ====="
dpkg-deb -c "$OUT"
echo "roothide deb written: $OUT"
