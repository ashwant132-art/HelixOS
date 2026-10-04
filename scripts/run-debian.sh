#!/usr/bin/env bash
set -euo pipefail
# Boot HelixOS (Debian trixie) rootfs in QEMU from ext4 image (LABEL=helixos)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Prefer native Linux build dir (WSL ext4), fallback to Windows drive copy
if [ -f "$HOME/helixos-build/vmlinuz-trixie" ]; then BUILD="$HOME/helixos-build"; else BUILD="$ROOT/build"; fi
# legacy my-os-build fallback
if [ ! -f "$BUILD/vmlinuz-trixie" ] && [ -f "$HOME/my-os-build/vmlinuz-trixie" ]; then BUILD="$HOME/my-os-build"; fi
LD_IMG="helixos-trixie.ext4"
if [ ! -f "$BUILD/$LD_IMG" ] && [ -f "$BUILD/my-os-trixie.ext4" ]; then LD_IMG="my-os-trixie.ext4"; fi
exec qemu-system-x86_64 \
  -kernel "$BUILD/vmlinuz-trixie" \
  -initrd "$BUILD/initrd-trixie" \
  -append "root=LABEL=helixos rw console=ttyS0 systemd.unit=multi-user.target" \
  -drive file="$BUILD/$LD_IMG",format=raw,if=virtio \
  -nographic -m 1024 -smp 1 \
  -net nic -net user,hostfwd=tcp::2222-:22
