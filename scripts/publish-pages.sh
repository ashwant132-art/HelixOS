#!/usr/bin/env bash
set -euo pipefail
# Publishes HelixOS debs as a signed apt repo on GitHub Pages ($0 pipeline).
# Layout in repo branch: dists/trixie/main/binary-amd64/{Packages,Release,...}
# Usage: GPGKEY=5C58E6D7... ./scripts/publish-pages.sh [testing|stable]
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUITE="${1:-testing}"
GPGKEY="${GPGKEY:-}"
GH_USER="${GH_USER:-ashwant132-art}"
REPO_NAME="${REPO_NAME:-HelixOS}"
WORK="$ROOT/build/apt-repo"

[ -n "$GPGKEY" ] || { echo "Set GPGKEY env to your key id (gpg --list-secret-keys)"; exit 1; }
mkdir -p "$WORK/dists/trixie/main/binary-amd64"
cp -vf "$ROOT"/packages/*.deb "$WORK/" 2>/dev/null || echo "No debs yet — run ./scripts/build-debs.sh first."
mv -f "$WORK"/*.deb "$WORK/dists/trixie/main/binary-amd64/" 2>/dev/null || true
cd "$WORK"
apt-ftparchive packages dists/trixie/main/binary-amd64 > dists/trixie/main/binary-amd64/Packages
gzip -kf dists/trixie/main/binary-amd64/Packages
apt-ftparchive release -o APT::FTPArchive::Release::Origin=HelixOS \
  -o APT::FTPArchive::Release::Label=HelixOS \
  -o APT::FTPArchive::Release::Suite="$SUITE" \
  -o APT::FTPArchive::Release::Codename=trixie \
  dists/trixie > dists/trixie/Release
gpg --default-key "$GPGKEY" -abs -o dists/trixie/Release.gpg dists/trixie/Release
gpg --default-key "$GPGKEY" --clearsign -o dists/trixie/InRelease dists/trixie/Release
echo "Repo ready in $WORK — push to branch 'repo' and enable Pages:"
echo "  cd $WORK && git init -b repo && git remote add origin <your-remote> && git add -A && git commit -m 'repo $SUITE' && git push -f origin repo"
echo "Clients use: https://$GH_USER.github.io/$REPO_NAME trixie main"
