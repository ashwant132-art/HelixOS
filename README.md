# HelixOS 1.0 “Surge”

HelixOS is a usable desktop OS built on Debian 13 “trixie” — tuned for
older and low-RAM machines (4 GB first, everything else after). Plasma
desktop, Debian package universe, Calamares guided setup, quiet boot,
and a dual-boot friendly bootloader story out of the box.

Status: pre-alpha. It boots on real hardware from a live USB.
Daily-driver and installer testing is in progress — expect rough edges.

## Try it

1. Build the live ISO (WSL Ubuntu):
   ```bash
   ./scripts/setup-wsl.sh
   ./scripts/make-iso.sh
   ```
2. Flash `helixos-live.iso` with Rufus (DD mode), Secure Boot off for now.
3. Boot the USB, pick Try HelixOS. Live user `helix`, no password.
4. Double-click Install HelixOS for the guided setup (language,
   timezone, keyboard, user + password). preferably on a spare disk.

## Layout

- `scripts/make-iso.sh` — official Debian live-build pipeline + EFI injection
- `scripts/add-efi.sh` — Secure Boot chain + dual BIOS/UEFI image assembly
- `scripts/build-debs.sh` — builds the `helixos-*` OTA packages
- `scripts/publish-pages.sh` — publishes the signed apt repo (GitHub Pages)
- `configs/` — GRUB entries, desktop defaults, Calamares branding, lockdown
- `packages/helixos-base/` — base identity deb (OTA channel)
- `docs/ROADMAP.md` — where this is going

## Updates

Installed systems update through APT like any Debian system
(Discover works as the graphical updater). HelixOS system packages
ship through our signed repo; base system tracks Debian trixie.

## Contribute

Testers wanted — especially AMD CPUs and old 4 GB machines.
Boot the live USB, fill the hardware sheet in Issues, paste failures
with photos of the screen. Docs, translations, and packaging help
welcome. Be kind, paste logs.

## License

To be announced.
