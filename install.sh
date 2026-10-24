#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  echo "Usage: sudo $0 --vm NAME --gpu DDDD:BB:SS.F [--audio DDDD:BB:SS.F] [--settle SECONDS]" >&2
}

vm=''
gpu=''
audio=''
settle=10
while (($#)); do
  case $1 in
    --vm) vm=${2:-}; shift 2 ;;
    --gpu) gpu=${2:-}; shift 2 ;;
    --audio) audio=${2:-}; shift 2 ;;
    --settle) settle=${2:-}; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done

if [[ $EUID -ne 0 || -z $vm || -z $gpu ]]; then
  usage
  exit 2
fi

readonly bdf_pattern='^[[:xdigit:]]{4}:[[:xdigit:]]{2}:[[:xdigit:]]{2}\.[0-7]$'
if [[ ! $vm =~ ^[A-Za-z0-9_.-]+$ ]]; then
  echo "Invalid VM name: $vm" >&2
  exit 2
fi
if [[ ! $gpu =~ $bdf_pattern ]]; then
  echo "Invalid GPU address: $gpu" >&2
  exit 2
fi
if [[ -n $audio && ! $audio =~ $bdf_pattern ]]; then
  echo "Invalid audio address: $audio" >&2
  exit 2
fi
if [[ ! $settle =~ ^[0-9]+$ ]] || (( settle < 1 || settle > 60 )); then
  echo "--settle must be an integer from 1 to 60." >&2
  exit 2
fi

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly source_dir
readonly helper_dir=/usr/local/libexec/raphael-igpu-reset
readonly hook_dir=/etc/libvirt/hooks/qemu.d
readonly config=/etc/raphael-igpu-reset.conf
readonly installed_helper=$helper_dir/reseed
readonly installed_evidence=$helper_dir/mode2-reset-evidence.sh
readonly installed_hook=$hook_dir/50-raphael-igpu-reset

for target in "$config" "$installed_helper" "$installed_evidence" "$installed_hook"; do
  if [[ -e $target ]]; then
    echo "Refusing to overwrite existing path: $target" >&2
    echo "Run uninstall.sh first if this project created it." >&2
    exit 1
  fi
done

if [[ ! -e /sys/bus/pci/devices/$gpu ]]; then
  echo "GPU $gpu was not found in sysfs." >&2
  exit 1
fi
if [[ -n $audio && ! -e /sys/bus/pci/devices/$audio ]]; then
  echo "Audio device $audio was not found in sysfs." >&2
  exit 1
fi

bash -n "$source_dir/reseed"
bash -n "$source_dir/mode2-reset-evidence.sh"
bash -n "$source_dir/50-raphael-igpu-reset"

temporary=$(mktemp /etc/raphael-igpu-reset.conf.XXXXXX)
trap '[[ ! -e $temporary ]] || unlink "$temporary"' EXIT
printf "VM_NAME='%s'\nGPU_BDF='%s'\nAUDIO_BDF='%s'\nSETTLE_SECONDS='%s'\n" \
  "$vm" "$gpu" "$audio" "$settle" >"$temporary"
printf "EXPECTED_GPU_ID='1002:164e'\nEXPECTED_AUDIO_ID='1002:1640'\n" >>"$temporary"

install -d -m 0755 "$helper_dir" "$hook_dir"
install -m 0755 "$source_dir/reseed" "$installed_helper"
install -m 0644 "$source_dir/mode2-reset-evidence.sh" "$installed_evidence"
install -m 0755 "$source_dir/50-raphael-igpu-reset" "$installed_hook"
install -m 0600 "$temporary" "$config"
unlink "$temporary"
trap - EXIT

echo "Installed for VM=$vm GPU=$gpu AUDIO=${audio:-not-configured}."
echo "Restart libvirtd or virtqemud with all guests shut down."
