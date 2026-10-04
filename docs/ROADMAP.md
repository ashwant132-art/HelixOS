#!/usr/bin/env bash
set -euo pipefail
# Phase 1 roadmap: Linux-based desktop OS

## Milestone 1 — Minimal boot (now)
- [x] WSL Ubuntu 24.04 toolchain
- [ ] `setup-wsl.sh` installs qemu-system-x86, build-essential, bc, flex, bison, libssl-dev, libelf-dev, cpio
- [ ] `build.sh` builds: vanilla kernel 6.8.x (defconfig + tweaks) + static BusyBox + initramfs
- [ ] `run.sh` boots with `qemu-system-x86_64 -kernel -initrd`
- Success: shell prompt `my-os:/ #`

## Milestone 2 — Real userspace
- Switch init script -> /sbin/init with hostname, mounts (/proc /sys /dev), DHCP
- Add dropbear (ssh), strace, vim-tiny
- Move from initramfs-only to ext4 rootfs image
- Pick base strategy: Buildroot (simple) vs Yocto (flexible) vs debootstrap (Debian-based)

## Milestone 3 — Graphics / Desktop
- Enable DRM, KMS, evdev in kernel config
- Mesa + Wayland + Weston or Labwc + foot terminal
- Seat management (seatd), font (terminus), your wallpaper/branding
- Run with: `qemu -vga virtio -display gtk`

## Milestone 4 — Distro polish
- ISO via xorriso/grub, installer script
- User accounts, package manager choice (apt if Debian-based, apk if Alpine-based)
- OTA updates, versioning, LICENSE, README screenshots

## What NOT to do yet
- Don't write your own scheduler/filesystem/GPU driver
- Don't fork the kernel — use vanilla + out-of-tree modules only
- Don't target real hardware until QEMU boot is solid
