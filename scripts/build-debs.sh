#!/usr/bin/env bash
set -euo pipefail
# Builds HelixOS .debs (OTA payloads) — needs: sudo apt install build-essential debhelper
# Usage: ./scripts/build-debs.sh  ->  packages/*.deb
# NOTE: builds on native ext4. /mnt/d (DrvFs) marks every file executable,
# which makes debhelper misread debian/install as a script.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$HOME/helixos-pkg"
sudo apt-get update
sudo apt-get install -y build-essential debhelper
rm -rf "$STAGE"
mkdir -p "$STAGE"
for PKGDIR in "$ROOT"/packages/*/; do
  [ -f "$PKGDIR/debian/control" ] || continue
  PKG="$(basename "$PKGDIR")"
  echo "=== building $PKG (staged from $PKGDIR) ==="
  rm -rf "$STAGE/$PKG"
  cp -a "$PKGDIR" "$STAGE/$PKG"
  chmod +x "$STAGE/$PKG/debian/rules"
  chmod -x "$STAGE/$PKG/debian/control" "$STAGE/$PKG/debian/changelog" "$STAGE/$PKG/debian/install" 2>/dev/null || true
  ls -l "$STAGE/$PKG/debian/"
  (cd "$STAGE/$PKG" && dpkg-buildpackage -us -uc -b)
  cp -vf "$STAGE"/${PKG}_*.deb "$ROOT/packages/" 2>/dev/null || cp -vf "$STAGE"/*.deb "$ROOT/packages/"
done
echo "Debs land in $ROOT/packages/ — upload to the apt repo (testing first)."
