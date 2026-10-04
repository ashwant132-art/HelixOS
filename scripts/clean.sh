#!/usr/bin/env bash
set -euo pipefail
# SAFE clean for HelixOS builds — unmounts binds before rm (prevents /dev/null destruction)
for base in "$HOME/helixos-build" "$HOME/my-os-build"; do
  for mnt in "$base/debian-trixie/proc" "$base/debian-trixie/sys" "$base/debian-trixie/dev"; do
    sudo umount -R "$mnt" 2>/dev/null || true
  done
  sudo rm -rf "$base" 2>/dev/null || true
done
echo "CLEAN OK. Verify host /dev/null: ls -l /dev/null (want: crw-rw-rw-)"
ls -l /dev/null || echo "HOST /dev/null BROKEN -> run: wsl --shutdown  (from Windows), reopen, retry"
