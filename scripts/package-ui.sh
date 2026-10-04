#!/usr/bin/env bash
set -euo pipefail
# Packages your Qt Designer .ui into HelixOS locked image (no Edit Mode for users)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -d "$HOME/helixos-build/debian-trixie" ]; then BUILD="$HOME/helixos-build"; else BUILD="$ROOT/build"; fi
ROOTFS="$BUILD/debian-trixie"
sudo mkdir -p "$ROOTFS/usr/share/helixos" "$ROOTFS/etc/xdg"
sudo cp "$ROOT/configs/helix-shell/helix-tabs.ui" "$ROOTFS/usr/share/helixos/"
sudo cp "$ROOT/configs/helix-shell/kdeglobals-locked" "$ROOTFS/etc/xdg/kdeglobals"
echo "HelixOS locked UI packaged. Users get your tabs, no Edit Mode."
