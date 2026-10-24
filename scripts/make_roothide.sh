#!/usr/bin/env bash
# Convert a rootful deb into a roothide (jbroot-relocatable) deb.
# Works with the standard roothide bootstrap, whose dpkg relocates every
# path under jbroot/ at install time.
#
# Usage: ./scripts/make_roothide.sh <input.deb> <output.deb>
set -euo pipefail

SRC="${1:?usage: make_roothide.sh <input.deb> <output.deb>}"
OUT="${2:?usage: make_roothide.sh <input.deb> <output.deb>}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
ar x "$SRC"

# stage data + control
mkdir root/DEBIAN
tar -xzf control.tar.gz -C root/DEBIAN
for f in data.tar.*; do tar -xf "$f" -C root; done

# relocate every data path under jbroot/
cd root
mkdir -p jbroot
for d in $(ls -A | grep -v -e '^DEBIAN$' -e '^jbroot$'); do
  mv "$d" jbroot/
done
cd ..

# keep control as-is (roothide's ellekit Provides: mobilesubstrate)
dpkg-deb --root-owner-group -b root "$OUT"
echo "roothide deb written: $OUT"
