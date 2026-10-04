#!/usr/bin/env bash
set -euo pipefail
# Builds HelixOS .debs (OTA payloads) — needs: sudo apt install build-essential debhelper
# Usage: ./scripts/build-debs.sh  ->  packages/*.deb
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
sudo apt-get update
sudo apt-get install -y build-essential debhelper
for PKGDIR in "$ROOT"/packages/*/; do
  [ -f "$PKGDIR/debian/control" ] || continue
  echo "=== building $(basename "$PKGDIR") ==="
  (cd "$PKGDIR" && dpkg-buildpackage -us -uc -b)
done
echo "Debs land in $ROOT/packages/ — upload to the apt repo (testing first)."
