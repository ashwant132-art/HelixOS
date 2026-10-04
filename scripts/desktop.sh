#!/usr/bin/env bash
set -euo pipefail
# Installs HelixOS desktop into Debian trixie rootfs (run AFTER debian-rootfs.sh)
# NO-CODE UI: KDE Plasma + SDDM. You build UI with mouse in Edit Mode, zero config files.
# Labwc kept as lightweight fallback session.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -d "$HOME/helixos-build/debian-trixie" ]; then BUILD="$HOME/helixos-build"; elif [ -d "$HOME/my-os-build/debian-trixie" ]; then BUILD="$HOME/my-os-build"; else BUILD="$ROOT/build"; fi
ROOTFS="$BUILD/debian-trixie"
CONF="$ROOT/configs/desktop"

if [ ! -d "$ROOTFS" ]; then
  echo "Run ./scripts/debian-rootfs.sh first (no $ROOTFS)"
  exit 1
fi

sudo mount -t proc none "$ROOTFS/proc" 2>/dev/null || true
sudo mount --rbind /sys "$ROOTFS/sys" 2>/dev/null || true
sudo mount --rbind /dev "$ROOTFS/dev" 2>/dev/null || true
INNER="$(mktemp /tmp/helix-desktop-XXXX.sh)"
cat > "$INNER" <<'INNER_EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
# Full HelixOS Plasma suite: settings, taskbar/panel, start menu, tray, terminal, taskmgr, store
# settings=systemsettings, start menu=plasma kickoff (in plasma-desktop), tray=plasma systemtray,
# terminal=konsole, taskmanager=plasma-systemmonitor, store=plasma-discover
apt-get install -y --no-install-recommends kde-plasma-desktop sddm \
  systemsettings dolphin konsole kate okular ark spectacle \
  plasma-systemmonitor plasma-discover plasma-nm plasma-pa \
  fonts-noto-core fonts-hack network-manager \
  pipewire wireplumber mesa-utils
# fallback lightweight session
apt-get install -y labwc foot wofi thunar mousepad grim slurp wl-clipboard || true
# Plasma + SDDM is default (visual). Disable greetd so they don't fight.
systemctl enable sddm || true
systemctl disable greetd 2>/dev/null || true
systemctl enable NetworkManager || true
INNER_EOF
sudo cp "$INNER" "$ROOTFS/tmp/inner-desktop.sh"
sudo chroot "$ROOTFS" /bin/bash /tmp/inner-desktop.sh
sudo rm -f "$ROOTFS/tmp/inner-desktop.sh"
rm -f "$INNER"
sudo umount -R "$ROOTFS/proc" 2>/dev/null || true
sudo umount -R "$ROOTFS/sys" 2>/dev/null || true
sudo umount -R "$ROOTFS/dev" 2>/dev/null || true

# push HelixOS energy defaults (wallpaper + SDDM theme). Plasma user tweaks override these visually.
sudo mkdir -p "$ROOTFS/usr/share/backgrounds" "$ROOTFS/etc/sddm.conf.d" "$ROOTFS/home/helix/.config/labwc" \
  "$ROOTFS/home/helix/.config/waybar" "$ROOTFS/home/helix/.config/foot"
sudo cp "$CONF/helixos-wallpaper.svg" "$ROOTFS/usr/share/backgrounds/helixos-wallpaper.svg"
printf '[Theme]\nCurrent=breeze\n[General]\nHaltCommand=/bin/systemctl poweroff\nRebootCommand=/bin/systemctl reboot\n' | sudo tee "$ROOTFS/etc/sddm.conf.d/helixos.conf"
printf '[Autologin]\nUser=helix\nSession=plasma.desktop\n' | sudo tee -a "$ROOTFS/etc/sddm.conf.d/helixos.conf"
# Labwc fallback configs (optional session)
sudo cp "$CONF/labwc-autostart" "$ROOTFS/home/helix/.config/labwc/autostart" 2>/dev/null || true
sudo cp "$CONF/labwc-rc.xml" "$ROOTFS/home/helix/.config/labwc/rc.xml" 2>/dev/null || true
sudo cp "$CONF/waybar-config" "$ROOTFS/home/helix/.config/waybar/config" 2>/dev/null || true
sudo cp "$CONF/waybar-style.css" "$ROOTFS/home/helix/.config/waybar/style.css" 2>/dev/null || true
sudo cp "$CONF/foot.ini" "$ROOTFS/home/helix/.config/foot/foot.ini" 2>/dev/null || true
# legacy myos home migration
if [ -d "$ROOTFS/home/myos" ] && [ ! -d "$ROOTFS/home/helix" ]; then sudo mv "$ROOTFS/home/myos" "$ROOTFS/home/helix"; fi
sudo chroot "$ROOTFS" chown -R 1000:1000 /home/helix/.config 2>/dev/null || true

echo "DESKTOP OK (Plasma visual, no code needed). Rebuild image with: ./scripts/repack-image.sh"
echo "Then boot GUI: ./scripts/run-gui.sh"
