#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
KVER="6.8.9"
KJAR="linux-${KVER}.tar.xz"
KURL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KJAR}"
BBVER="1.36.1"
BBTAR="busybox-${BBVER}.tar.bz2"
BBURL="https://busybox.net/downloads/${BBTAR}"

mkdir -p "$BUILD"
cd "$BUILD"

# 1. kernel source
if [ ! -d "linux-${KVER}" ]; then
  [ -f "$KJAR" ] || wget "$KURL"
  tar xf "$KJAR"
fi

# 2. busybox source
if [ ! -d "busybox-${BBVER}" ]; then
  [ -f "$BBTAR" ] || wget "$BBURL"
  tar xf "$BBTAR"
fi

# 3. build busybox (static)
cd "busybox-${BBVER}"
make defconfig
# force static
sed -i 's/.*CONFIG_STATIC.*/CONFIG_STATIC=y/' .config
make -j"$(nproc)" busybox
cd ..

# 4. build kernel (defconfig, small)
cd "linux-${KVER}"
make defconfig
# ensure initramfs-friendly options
./scripts/config -e PRINTK -e TTY -e SERIAL_8250 -e SERIAL_8250_CONSOLE \
  -e PROC_FS -e SYSFS -e DEVTMPFS -e DEVTMPFS_MOUNT -e TMPFS -e BLK_DEV_INITRD
make -j"$(nproc)" bzImage
cd ..

# 5. assemble initramfs
rm -rf initramfs && mkdir -p initramfs/bin initramfs/sbin initramfs/proc initramfs/sys initramfs/dev
cp "busybox-${BBVER}/busybox" initramfs/bin/
cp "$ROOT/init/init" initramfs/init
chmod +x initramfs/init
(cd initramfs/bin && ln -sf busybox sh)
cd initramfs
find . -print0 | cpio --format=newc --create --null | gzip -9 > "$BUILD/initramfs.cpio.gz"
cd ..
cp "linux-${KVER}/arch/x86/boot/bzImage" "$BUILD/bzImage"

echo "BUILD OK:"
ls -lh "$BUILD/bzImage" "$BUILD/initramfs.cpio.gz"
echo "Run: ./scripts/run.sh"
