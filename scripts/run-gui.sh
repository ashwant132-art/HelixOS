#!/usr/bin/env bash
set -euo pipefail
# Boot HelixOS with GUI (virtio-gpu, no -nographic)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$HOME/helixos-build/vmlinuz-trixie" ]; then BUILD="$HOME/helixos-build"; else BUILD="$ROOT/build"; fi
if [ ! -f "$BUILD/vmlinuz-trixie" ] && [ -f "$HOME/my-os-build/vmlinuz-trixie" ]; then BUILD="$HOME/my-os-build"; fi
LD_IMG="helixos-trixie.ext4"
if [ ! -f "$BUILD/$LD_IMG" ] && [ -f "$BUILD/my-os-trixie.ext4" ]; then LD_IMG="my-os-trixie.ext4"; fi
exec qemu-system-x86_64 \
  -kernel "$BUILD/vmlinuz-trixie" \
  -initrd "$BUILD/initrd-trixie" \
  -append "root=LABEL=helixos rw console=ttyS0 systemd.unit=graphical.target" \
  -drive file="$BUILD/$LD_IMG",format=raw,if=virtio \
  -vga virtio -display gtk -m 1536 -smp 2 \
  -device virtio-net-pci,netdev=n0 -netdev user,id=n0,hostfwd=tcp::2222-:22 \
  -device virtio-snd-pci -usb -device usb-tablet
