#!/usr/bin/env bash
set -euo pipefail
# Repack ROOTFS dir changes (desktop.sh, package-ui.sh) back into ext4 image — no loop mount (WSL-safe)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -d "$HOME/helixos-build/debian-trixie" ]; then BUILD="$HOME/helixos-build"; elif [ -d "$HOME/my-os-build/debian-trixie" ]; then BUILD="$HOME/my-os-build"; else BUILD="$ROOT/build"; fi
WIN_BUILD="$ROOT/build"
ROOTFS="$BUILD/debian-trixie"
IMG="$BUILD/helixos-trixie.ext4"
if [ ! -f "$IMG" ] && [ -f "$BUILD/my-os-trixie.ext4" ]; then IMG="$BUILD/my-os-trixie.ext4"; fi
# NEVER mkfs over live binds: drop stale proc/sys/dev first (leftover from failed desktop.sh)
sudo umount -R "$ROOTFS/proc" 2>/dev/null || true
sudo umount -R "$ROOTFS/sys" 2>/dev/null || true
sudo umount -R "$ROOTFS/dev" 2>/dev/null || true
if mountpoint -q "$ROOTFS/proc" || mountpoint -q "$ROOTFS/sys" || mountpoint -q "$ROOTFS/dev"; then
  echo "ERROR: stale mounts still active under $ROOTFS. Reboot WSL (wsl --shutdown) and retry."
  exit 1
fi
sudo rm -f "$IMG"
sudo chown -R "$(id -u):$(id -g)" "$BUILD" 2>/dev/null || true
sudo mkfs.ext4 -L helixos -d "$ROOTFS" "$IMG" 8G
sudo chown "$(id -u):$(id -g)" "$IMG" 2>/dev/null || true
cp -vf "$IMG" "$WIN_BUILD"/ 2>/dev/null || true
echo "REPACK OK: $IMG"
