#!/usr/bin/env bash
set -euo pipefail
# HelixOS: Debian 13 "trixie" (latest stable, 13.7 as of Sep 2026, kernel 6.12) rootfs
# Run in WSL Ubuntu: ./scripts/debian-rootfs.sh
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WIN_BUILD="$ROOT/build"
# IMPORTANT: debootstrap tar fails on /mnt/d (NTFS/DrvFs). Build on native ext4.
LIN_BUILD="$HOME/helixos-build"
BUILD="$LIN_BUILD"
DEB_RELEASE="trixie"
MIRROR="http://deb.debian.org/debian"
ROOTFS="$BUILD/debian-trixie"
IMG="$BUILD/helixos-trixie.ext4"
IMG_SIZE_GB="8"

sudo apt-get update
sudo apt-get install -y debootstrap debian-archive-keyring qemu-utils e2fsprogs arch-test 2>/dev/null || true

# SAFE CLEAN: unmount stale binds FIRST — never rm -rf through a live mount
sudo umount -R "$ROOTFS/proc" 2>/dev/null || true
sudo umount -R "$ROOTFS/sys" 2>/dev/null || true
sudo umount -R "$ROOTFS/dev" 2>/dev/null || true
sudo rm -rf "$ROOTFS"
sudo mkdir -p "$ROOTFS"
sudo debootstrap --arch=amd64 "$DEB_RELEASE" "$ROOTFS" "$MIRROR"

# branding + base config
echo "helix" | sudo tee "$ROOTFS/etc/hostname"
echo "127.0.0.1 localhost helix" | sudo tee "$ROOTFS/etc/hosts"
echo "HelixOS 0.2 (Debian 13 trixie)" | sudo tee "$ROOTFS/etc/helixos-release"

# sources (stable + security + updates)
sudo tee "$ROOTFS/etc/apt/sources.list" <<EOF
deb $MIRROR $DEB_RELEASE main contrib non-free non-free-firmware
deb $MIRROR $DEB_RELEASE-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security $DEB_RELEASE-security main contrib non-free non-free-firmware
EOF

# install kernel + userspace inside chroot (with /proc /sys /dev mounted)
sudo mkdir -p "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/dev"
# drop stale mounts from previous failed run
sudo umount -R "$ROOTFS/proc" 2>/dev/null || true
sudo umount -R "$ROOTFS/sys" 2>/dev/null || true
sudo umount -R "$ROOTFS/dev" 2>/dev/null || true
sudo mount -t proc none "$ROOTFS/proc" || true
sudo mount --rbind /sys "$ROOTFS/sys" || true
sudo mount --make-rslave "$ROOTFS/sys" 2>/dev/null || true
sudo mount --rbind /dev "$ROOTFS/dev" || true
sudo mount --make-rslave "$ROOTFS/dev" 2>/dev/null || true
# write inner setup to /tmp (user-writable, avoids root-owned BUILD perms)
INNER="$(mktemp /tmp/helix-inner-XXXX.sh)"
cat > "$INNER" <<'INNER_EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y linux-image-amd64 systemd systemd-sysv openssh-server network-manager sudo vim-tiny less net-tools iproute2 iputils-ping labwc foot weston mesa-utils seatd
useradd -m -s /bin/bash -G sudo helix || true
echo 'helix:helix' | chpasswd
echo 'root:root' | chpasswd
systemctl enable NetworkManager || true
systemctl enable ssh || true
systemctl enable seatd || true
apt-get clean
INNER_EOF
sudo cp "$INNER" "$ROOTFS/tmp/inner-setup.sh"
sudo chroot "$ROOTFS" /bin/bash /tmp/inner-setup.sh || { echo "CHROOT FAILED - see above"; sudo umount -R "$ROOTFS/proc" 2>/dev/null || true; sudo umount -R "$ROOTFS/sys" 2>/dev/null || true; sudo umount -R "$ROOTFS/dev" 2>/dev/null || true; exit 1; }
sudo rm -f "$ROOTFS/tmp/inner-setup.sh"
rm -f "$INNER"
sudo umount -R "$ROOTFS/proc" 2>/dev/null || true
sudo umount -R "$ROOTFS/sys" 2>/dev/null || true
sudo umount -R "$ROOTFS/dev" 2>/dev/null || true

# copy out kernel/initrd for QEMU -kernel boot (easiest, no grub needed yet)
if ! sudo ls "$ROOTFS/boot/vmlinuz-"* >/dev/null 2>&1; then
  echo "ERROR: no kernel in $ROOTFS/boot. Kernel install failed - check apt log above."
  exit 1
fi
KVER=$(sudo ls "$ROOTFS/boot/vmlinuz-"* | head -n1 | sed 's/.*vmlinuz-//')
echo "Debian kernel: $KVER"
sudo cp -v "$ROOTFS/boot/vmlinuz-$KVER" "$BUILD/vmlinuz-trixie"
sudo cp -v "$ROOTFS/boot/initrd.img-$KVER" "$BUILD/initrd-trixie"
sudo chmod 644 "$BUILD/vmlinuz-trixie" "$BUILD/initrd-trixie"
sudo chown "$(id -u):$(id -g)" "$BUILD/vmlinuz-trixie" "$BUILD/initrd-trixie" || true

# pack rootfs dir into bootable ext4 image WITHOUT loop mount (WSL-safe via mkfs -d)
echo "Creating $IMG (${IMG_SIZE_GB}G, no loop mount)..."
sudo rm -f "$IMG" "$ROOTFS/tmp/inner-setup.sh" 2>/dev/null || true
sudo chown -R "$(id -u):$(id -g)" "$BUILD" 2>/dev/null || true
echo "LABEL=helixos / ext4 defaults 0 1" | sudo tee "$ROOTFS/etc/fstab"
# 8G image from directory contents directly (sudo: needs root for -d)
sudo mkfs.ext4 -L helixos -d "$ROOTFS" "$IMG" "${IMG_SIZE_GB}G"
sudo chown "$(id -u):$(id -g)" "$IMG" "$BUILD/vmlinuz-trixie" "$BUILD/initrd-trixie" || true
ls -lh "$IMG" "$BUILD/vmlinuz-trixie" "$BUILD/initrd-trixie"

# mirror artifacts back to Windows drive for storage (QEMU scripts check both)
mkdir -p "$WIN_BUILD"
cp -vf "$IMG" "$BUILD/vmlinuz-trixie" "$BUILD/initrd-trixie" "$WIN_BUILD"/
echo "Mirrored to $WIN_BUILD/"

echo "ROOTFS OK: $ROOTFS"
echo "KERNEL: $BUILD/vmlinuz-trixie"
echo "Boot HelixOS with: ./scripts/run-debian.sh"
echo "Login: helix/helix or root/root"
