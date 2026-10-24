#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run this script as root." >&2
  exit 2
fi

for target in \
  /etc/libvirt/hooks/qemu.d/50-raphael-igpu-reset \
  /usr/local/libexec/raphael-igpu-reset/reseed \
  /usr/local/libexec/raphael-igpu-reset/mode2-reset-evidence.sh \
  /etc/raphael-igpu-reset.conf; do
  [[ ! -e $target ]] || unlink "$target"
done

echo "Removed the hook, helper and configuration. Logs were preserved."
echo "Restart libvirtd or virtqemud with all guests shut down."
