#!/bin/sh
# HelixOS dual-boot: install rEFInd boot manager into the installed system's ESP.
# Runs in the LIVE session at the end of setup (Calamares shellprocess, dontChroot).
# Partition choice happens in setup's partitioning step (alongside/manual);
# the ESP is auto-detected — no manual dropdowns to get wrong.
# Never fails the install: worst case logs + manual fallback below.
LOG=/tmp/helixos-refind.log
{
  echo "=== helixos-refind-install $(date -u) ==="
  ROOT="$(mount | awk '$3 ~ /^\/tmp\/calamares-root/ {print $3}' | head -n1)"
  if [ -z "$ROOT" ]; then
    echo "SKIP: no Calamares target mounted (live-only run?)"
    exit 0
  fi
  echo "target: $ROOT"
  if [ ! -d "$ROOT/boot/efi" ]; then
    echo "SKIP: no ESP mounted at $ROOT/boot/efi (legacy-BIOS install?)"
    exit 0
  fi
  if refind-install --root "$ROOT" --yes; then
    echo "OK: rEFInd installed — reboot shows HelixOS + Windows picker"
  else
    echo "FAIL: run manually after install: sudo refind-install"
  fi
} >> "$LOG" 2>&1
exit 0
