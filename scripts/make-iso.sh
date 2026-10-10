#!/usr/bin/env bash
set -euo pipefail
# HelixOS official ISO via Debian live-build (tested bootloader/installer, trixie)
# Run in WSL: ./scripts/make-iso.sh  ->  ~/helixos-iso/live-image-amd64.hybrid.iso
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LB_DIR="$HOME/helixos-iso"
CONF="$ROOT/configs/desktop"
SHELLCONF="$ROOT/configs/helix-shell"

sudo apt-get update
sudo apt-get install -y live-build debootstrap debian-archive-keyring cpio xorriso isolinux syslinux-efi syslinux-utils grub-efi-amd64-bin squashfs-tools imagemagick

# Patch noble's old live-build: trixie moved Contents indices per-component
# (dists/trixie/main/Contents-*.gz), scripts still fetch suite-level path (404).
for LBFIX in /usr/lib/live/build/lb_chroot_linux-image /usr/lib/live/build/lb_binary_debian-installer; do
  if grep -q 'dists/${LB_DISTRIBUTION}/Contents-' "$LBFIX" 2>/dev/null; then
    sudo sed -i 's|/dists/${LB_PARENT_DISTRIBUTION}/Contents-|/dists/${LB_PARENT_DISTRIBUTION}/main/Contents-|; s|/dists/${LB_DISTRIBUTION}/Contents-|/dists/${LB_DISTRIBUTION}/main/Contents-|' "$LBFIX"
    echo "Patched $LBFIX for per-component Contents."
  fi
done
# Patch debian-installer integration: drops 2006-era lilo/bare-grub/linux-image-2.6 names
DIFIX=/usr/lib/live/build/lb_binary_debian-installer
if grep -q 'DI_REQ_PACKAGES=' "$DIFIX" 2>/dev/null; then
  sudo sed -i 's/DI_REQ_PACKAGES="[^"]*"/DI_REQ_PACKAGES="grub-pc"/; s/linux-image-2\.6-amd64/linux-image-amd64/g' "$DIFIX"
  echo "Patched $DIFIX for trixie bootloader/kernel names."
fi

# Cached builds by default: reuse ~/helixos-iso (debootstrap + debs stay cached).
# Pass --clean for a from-scratch build.
if [ "${1:-}" = "--clean" ]; then
  sudo rm -rf "$LB_DIR"
fi
mkdir -p "$LB_DIR"
cd "$LB_DIR"
lb config \
  --mode debian \
  --distribution trixie \
  --initsystem systemd \
  --archive-areas "main contrib non-free non-free-firmware" \
  --security false \
  --mirror-bootstrap https://deb.debian.org/debian \
  --mirror-chroot https://deb.debian.org/debian \
  --mirror-binary https://deb.debian.org/debian \
  --linux-flavours amd64 \
  --linux-packages "linux-image" \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --bootloader syslinux \
  --debian-installer live \
  --iso-application HelixOS \
  --iso-preparer "HelixOS" \
  --iso-publisher "HelixOS" \
  --iso-volume HelixOS \
  --source false \
  --win32-loader false \
  --bootappend-live "boot=live components username=helix quiet"

# HelixOS package set: full desktop — settings, panel/taskbar, kickoff start menu,
# system tray, konsole terminal, systemmonitor task manager, discover store, plymouth boot splash
mkdir -p config/package-lists
cat > config/package-lists/helixos.list.chroot <<'PKGS'
kde-plasma-desktop
sddm
systemsettings
dolphin
konsole
kate
okular
ark
kde-spectacle
plasma-systemmonitor
plasma-discover
plasma-nm
plasma-pa
firefox-esr
network-manager
pipewire
wireplumber
mesa-utils
plymouth
plymouth-themes
unattended-upgrades
packagekit
packagekit-tools
fonts-noto-core
fonts-hack
labwc
foot
thunar
mousepad
grim
slurp
wl-clipboard
isolinux
syslinux-utils
live-boot
live-config
live-config-systemd
live-tools
user-setup
eject
calamares
calamares-settings-debian
refind
os-prober
efibootmgr
PKGS

# base identity (no logos, no wallpapers, no custom themes)
mkdir -p config/includes.chroot/etc \
  config/includes.chroot/etc/sddm.conf.d \
  config/includes.chroot/etc/xdg
cp "$SHELLCONF/kdeglobals-locked" config/includes.chroot/etc/xdg/kdeglobals
echo "HelixOS 1.0 \"Surge\" (Debian 13 trixie)" > config/includes.chroot/etc/helixos-release
echo "helix" > config/includes.chroot/etc/hostname
# HelixOS OTA repo client — only wired when the operator has exported the pubkey
# (gpg --armor --export you@mail > helixos-repo-pub.asc in repo root). Secret keys NEVER ship.
if [ -f "$ROOT/helixos-repo-pub.asc" ]; then
  mkdir -p config/includes.chroot/usr/share/keyrings config/includes.chroot/etc/apt/sources.list.d
  cp "$ROOT/helixos-repo-pub.asc" config/includes.chroot/usr/share/keyrings/helixos-archive-keyring.asc
  GH_USER="${GH_USER:-ashwant132-art}"
  printf 'Types: deb\nURIs: https://%s.github.io/HelixOS\nSuites: trixie\nComponents: main\nArchitectures: amd64\nSigned-By: /usr/share/keyrings/helixos-archive-keyring.asc\n' "$GH_USER" > config/includes.chroot/etc/apt/sources.list.d/helixos.sources
  echo "OTA repo client wired."
fi
printf '[Theme]\nCurrent=breeze\n' > config/includes.chroot/etc/sddm.conf.d/helixos.conf
# Install-to-disk desktop icon for the live session (HelixOS installer identity)
mkdir -p config/includes.chroot/etc/skel/Desktop config/includes.chroot/usr/share/applications \
  config/includes.chroot/usr/share/pixmaps
cat > config/includes.chroot/usr/share/applications/helixos-install.desktop <<'DESK'
[Desktop Entry]
Name=Install HelixOS
Comment=Guided setup: language, timezone, keyboard, user and password
Exec=pkexec calamares -b helixos
Icon=helixos-logo
Terminal=false
Type=Application
Categories=System;
DESK
cp config/includes.chroot/usr/share/applications/helixos-install.desktop config/includes.chroot/etc/skel/Desktop/
cp "$SHELLCONF/helixos-logo.png" config/includes.chroot/usr/share/pixmaps/helixos-logo.png
# Calamares HelixOS branding (selected via calamares -b helixos, no system files patched)
mkdir -p config/includes.chroot/etc/calamares/branding/helixos
cp "$ROOT/configs/calamares/helixos/branding.desc" config/includes.chroot/etc/calamares/branding/helixos/
cp "$SHELLCONF/helixos-logo.png" config/includes.chroot/etc/calamares/branding/helixos/helixos-logo.png
# Dual-boot engine: rEFInd auto-installer (live-side script) + Calamares job config.
# The setup's partitioning step picks the partition (alongside/manual incl. Windows
# shrink); this job then drops rEFInd into the installed ESP automatically.
mkdir -p config/includes.chroot/usr/bin
cp "$ROOT/configs/calamares/helixos-refind-install.sh" config/includes.chroot/usr/bin/helixos-refind-install
chmod +x config/includes.chroot/usr/bin/helixos-refind-install
mkdir -p config/includes.chroot/etc/calamares/modules
cat > config/includes.chroot/etc/calamares/modules/shellprocess_helix-refind.conf <<'YML'
---
dontChroot: true
timeout: 300
script:
    - command: ["/usr/bin/helixos-refind-install"]
YML
# HelixOS GRUB menu (UEFI, 10s timeout) — binary includes land after the
# generated grub stages, so ours wins. EFI-embedded stub chainloads /boot/grub.
# (No theme: plain GRUB menu until new artwork lands.)
mkdir -p config/includes.binary/boot/grub
cp "$ROOT/configs/grub/grub.cfg" config/includes.binary/boot/grub/grub.cfg
# NOTE: Plymouth theme intentionally NOT shipped (boot splash stays stock).
# hooks live FLAT in config/hooks/ (live-build ignores subdirectories)
mkdir -p config/hooks
# Plymouth default reset: earlier builds set helixos theme inside the persistent
# chroot — that setting survives file purges, so point it back at stock explicitly.
cat > config/hooks/0099-helixos-plymouth-reset.hook.chroot <<'HOOK'
#!/bin/sh
plymouth-set-default-theme spinner 2>/dev/null || plymouth-set-default-theme text 2>/dev/null || true
HOOK
chmod +x config/hooks/0099-helixos-plymouth-reset.hook.chroot
# Setup sequencer patch: run the rEFInd dual-boot job right after the stock
# bootloader step. Guarded six ways — any mismatch skips silently (stock setup).
cat > config/hooks/0099-helixos-calamares-refind.hook.chroot <<'HOOK'
#!/bin/sh
python3 - <<'PYEOF' || true
import shutil
p = '/etc/calamares/settings.conf'
job = '/etc/calamares/modules/shellprocess_helix-refind.conf'
try:
    src = open(p).read().splitlines(keepends=True)
    have_job = False
    try:
        open(job).close()
        have_job = True
    except OSError:
        have_job = False
    hits = [i for i, l in enumerate(src) if l.strip() == '- bootloader']
    if have_job and len(hits) == 1 and not any('helix-refind' in l for l in src):
        shutil.copyfile(p, p + '.helixos-bak')
        src.insert(hits[0] + 1, '    - shellprocess@helix-refind\n')
        open(p, 'w').writelines(src)
        print('helix-refind job sequenced after bootloader')
    else:
        print('helix-refind sequencing skipped (already present or layout differs)')
except Exception as e:
    print('helix-refind sequencing skipped:', e)
PYEOF
HOOK
chmod +x config/hooks/0099-helixos-calamares-refind.hook.chroot
# (No Plymouth enable hook: stock splash until new artwork lands.)
# Live user helix: pre-created, EMPTY password, passwordless sudo.
# (live-config reuses the existing account at boot instead of inventing one.)
cat > config/hooks/0099-helixos-liveuser.hook.chroot <<'HOOK'
#!/bin/sh
set -e
id helix >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev helix
passwd -d helix
printf 'helix ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/helix-live
chmod 440 /etc/sudoers.d/helix-live
HOOK
chmod +x config/hooks/0099-helixos-liveuser.hook.chroot
# binary hook: populate isolinux dir with trixie syslinux modules (old live-build
# only copies the theme, leaving ldlinux.c32 et al behind -> "Failed to load ldlinux.c32")
cat > config/hooks/0099-helixos-syslinux-modules.hook.binary <<'HOOK'
#!/bin/sh
set -e
# Always (over)write: stale or version-skewed modules break the menu silently
for m in ldlinux.c32 libcom32.c32 libutil.c32 libmenu.c32 libgpl.c32 vesamenu.c32 menu.c32; do
  f="$(find chroot/usr/lib/syslinux chroot/usr/lib/ISOLINUX -name "$m" 2>/dev/null | head -n1)"
  if [ -n "$f" ]; then cp -v "$f" binary/isolinux/; else echo "WARNING: $m not found in chroot"; fi
done
HOOK
chmod +x config/hooks/0099-helixos-syslinux-modules.hook.binary
# rEFInd dual-boot picker on the USB: binaries from the live system, HelixOS-first
# config, auto-scans disk ESPs so Windows Boot Manager appears alongside HelixOS
cat > config/hooks/0099-helixos-refind.hook.binary <<'HOOK'
#!/bin/sh
set -e
REFIND="$(find chroot/usr/share -path '*refind*' -name 'refind_x64.efi' 2>/dev/null | head -n1)"
if [ -z "$REFIND" ]; then echo "WARNING: refind_x64.efi not in chroot (add refind to package list)"; exit 0; fi
mkdir -p binary/EFI/refind binary/efi-tools
cp -v "$REFIND" binary/EFI/refind/refind_x64.efi
cp -v "$REFIND" binary/efi-tools/refind_x64.efi
DRV="$(find chroot/usr/share -path '*refind*' -name 'ext4_x64.efi' 2>/dev/null | head -n1)"
if [ -n "$DRV" ]; then mkdir -p binary/EFI/refind/drivers_x64 && cp -v "$(dirname "$DRV")"/*.efi binary/EFI/refind/drivers_x64/; fi
cat > binary/EFI/refind/refind.conf <<'CONF'
timeout 10
scanfor internal,external,optical,manual
also_scan_dirs +EFI/refind
showtools shell,memtest,gdisk,mok_tool,about,hidden_tags,shutdown,reboot,firmware
menuentry "HelixOS Live" {
  volume HelixOS
  loader /live/vmlinuz
  initrd /live/initrd.img
  options "boot=live config username=helix quiet"
}
CONF
HOOK
chmod +x config/hooks/0099-helixos-refind.hook.binary

# Invalidate stages derived from our config so cached runs pick up flag/list changes
# (bootstrap + downloaded debs stay cached, only kernel/package stages re-run)
# NOTE: binary_syslinux is wiped with its target dir below, so its stamp must go too
rm -f .build/chroot_linux-image .build/chroot_package-lists.install .build/binary_syslinux .build/chroot_hooks
# Fix 2012-era absolute symlinks in syslinux theme: they must resolve INSIDE the
# trixie chroot (isolinux.bin lives in the isolinux deb, vesamenu in modules/bios)
sudo ln -sf /usr/lib/ISOLINUX/isolinux.bin /usr/share/live/build/bootloaders/isolinux/isolinux.bin
sudo ln -sf /usr/lib/syslinux/modules/bios/vesamenu.c32 /usr/share/live/build/bootloaders/isolinux/vesamenu.c32
# Seed trixie debian-cd metadata from sid (noble's live-build predates trixie)
if [ ! -d /usr/share/live/build/data/debian-cd/trixie ]; then
  sudo mkdir -p /usr/share/live/build/data/debian-cd/trixie
  sudo cp -r /usr/share/live/build/data/debian-cd/sid/* /usr/share/live/build/data/debian-cd/trixie/
  echo "Seeded trixie debian-cd data from sid."
fi
# Patch syslinux stage: bootlogo repack assumes a gfxboot archive the live-build
# theme never ships — skip repack when absent (vesamenu text menu still boots fine)
# Plus: kernel renames are not re-runnable (first pass already renamed vmlinuz-*
# to vmlinuz) — skip when globs match nothing
SYSFIX=/usr/lib/live/build/lb_binary_syslinux
if grep -q '(cd "$tmpdir" && cpio -i) < ${_TARGET}/bootlogo' "$SYSFIX" 2>/dev/null; then
  sudo sed -i 's|(cd "$tmpdir" && cpio -i) < ${_TARGET}/bootlogo|if [ -e "${_TARGET}/bootlogo" ]; then (cd "$tmpdir" \&\& cpio -i) < "${_TARGET}/bootlogo"; fi|' "$SYSFIX"
  echo "Patched $SYSFIX for missing bootlogo."
fi
if grep -q 'mv binary/live/vmlinuz-\* binary/live/vmlinuz$' "$SYSFIX" 2>/dev/null; then
  sudo sed -i 's|mv binary/live/vmlinuz-\* binary/live/vmlinuz$|if ls binary/live/vmlinuz-* >/dev/null 2>\&1; then mv binary/live/vmlinuz-* binary/live/vmlinuz; fi|; s|mv binary/live/initrd.img-\* binary/live/initrd.img$|if ls binary/live/initrd.img-* >/dev/null 2>\&1; then mv binary/live/initrd.img-* binary/live/initrd.img; fi|' "$SYSFIX"
  echo "Patched $SYSFIX for re-runnable kernel renames."
fi
# vesamenu.c32 fails to execute under QEMU SeaBIOS despite byte-valid modules —
# boot straight into the live system instead (UEFI path uses grub menu anyway)
printf 'default live-\nprompt 1\ntimeout 50\ninclude live.cfg\n' | sudo tee /usr/share/live/build/bootloaders/isolinux/isolinux.cfg > /dev/null
# rsvg compat shim: trixie dropped /usr/bin/rsvg (only rsvg-convert remains),
# but 2012 live-build calls: rsvg --format png --height H --width W IN OUT
sudo mkdir -p chroot/usr/bin
sudo tee chroot/usr/bin/rsvg > /dev/null <<'RSVG_EOF'
#!/bin/sh
# compat for old live-build: rsvg --format F --height H --width W IN OUT
format="png"; height=""; width=""; input=""; output=""
while [ $# -gt 0 ]; do
  case "$1" in
    --format) format="$2"; shift 2;;
    --height) height="$2"; shift 2;;
    --width) width="$2"; shift 2;;
    *) if [ -z "$input" ]; then input="$1"; else output="$1"; fi; shift;;
  esac
done
exec rsvg-convert --format "$format" --height "$height" --width "$width" --output "$output" "$input"
RSVG_EOF
sudo chmod +x chroot/usr/bin/rsvg
# Binary tree goes stale across partial runs (stages stamp "done" while their
# outputs are wiped or half-written) — full binary rebuild from intact chroot.
# chroot/ + caches are kept, so no re-downloads; only squashfs repacks (~15 min).
sudo rm -rf binary chroot/binary 2>/dev/null || true
rm -f .build/binary_*
# Remove dead hook subdirs from earlier runs (live-build only reads config/hooks/ flat)
rm -rf config/hooks/live config/hooks/binary 2>/dev/null || true
# Purge retired Helix artwork from the persistent chroot (includes only ADD —
# removed branding would otherwise ride along in every future squashfs)
sudo rm -rf chroot/usr/share/backgrounds/helixos-wallpaper.svg \
  chroot/usr/share/helixos \
  chroot/usr/share/plymouth/themes/helixos \
  chroot/usr/share/sddm/themes/breeze/theme.conf.user \
  chroot/etc/calamares/branding/helixos \
  chroot/etc/skel/.config/autostart/helixos-wallpaper.desktop \
  chroot/etc/skel/Desktop/helixos-install.desktop \
  chroot/usr/share/pixmaps/helixos-logo.png \
  chroot/etc/apt/sources.list.d/helixos-efi.list \
  chroot/etc/apt/sources.list.d/helixos-efi.sources 2>/dev/null || true
# Stale chroot mounts from killed runs abort the next build — drop them first
# (lazy fallback detaches even busy ones)
for _m in chroot/proc chroot/sys chroot/dev/pts chroot/selinux; do
  sudo umount -R "$_m" 2>/dev/null || sudo umount -l "$_m" 2>/dev/null || true
done
# Stale zsync artifacts abort the final stage (xz refuses to overwrite)
rm -f *.zsync *.zsync.xz 2>/dev/null || true
# Drop the accumulated install queue too — lb APPENDS to chroot/root/packages.chroot
# and failed runs never consume it, so stale names survive stamp resets
sudo rm -f config/packages.chroot/* config/packages.binary/* 2>/dev/null || true
sudo rm -f chroot/root/packages.chroot chroot/root/packages.binary cache/packages.chroot 2>/dev/null || true

sudo lb build
ls -lh *.hybrid.iso *.iso 2>/dev/null || true
mkdir -p "$ROOT/build"
ISO_OUT="$(ls -t helixos-live*.iso helixos-live*.hybrid.iso live-image*.iso binary.hybrid.iso 2>/dev/null | head -n1 || true)"
if [ -z "$ISO_OUT" ]; then echo "ERROR: no ISO produced"; exit 1; fi
# Inject UEFI (grub-efi) — old live-build has no such stage, trixie grub-legacy is hollow
bash "$ROOT/scripts/add-efi.sh" "$ISO_OUT" "$LB_DIR/helixos-live.iso"
cp -vf helixos-live.iso "$ROOT/build/helixos-live.iso" 2>/dev/null || sudo cp -vf helixos-live.iso "$ROOT/build/helixos-live.iso"
echo "ISO OK: $ROOT/build/helixos-live.iso (BIOS syslinux + UEFI grub, HelixOS theme) — flash Rufus, Secure Boot OFF, F12."
