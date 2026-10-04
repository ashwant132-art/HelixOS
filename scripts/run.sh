#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec qemu-system-x86_64 \
  -kernel "$ROOT/build/bzImage" \
  -initrd "$ROOT/build/initramfs.cpio.gz" \
  -nographic -append "console=ttyS0 panic=1" \
  -m 512 -smp 2
