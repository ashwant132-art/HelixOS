#!/usr/bin/env bash
set -euo pipefail
# Install OS-dev deps inside WSL Ubuntu
sudo apt-get update
sudo apt-get install -y \
  build-essential bc bison flex libssl-dev libelf-dev \
  qemu-system-x86 cpio wget curl git \
  busybox-static xorriso grub-pc-bin \
  debootstrap debian-archive-keyring qemu-utils e2fsprogs
echo "setup done. check: qemu-system-x86_64 --version"
