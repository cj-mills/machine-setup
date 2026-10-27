#!/usr/bin/env bash
# Lay out a disk for a fresh Windows install: a new GPT with its own EFI system
# partition and the Microsoft reserved partition, the rest left unallocated for
# Windows Setup. Giving the Windows disk its own ESP up front is half of keeping
# Windows' boot files off other drives; windows/machine-setup/ensure-own-esp.ps1
# is the other half.
#
# Works on a disk image file (test VM) or a whole disk. A whole disk must be given
# by its /dev/disk/by-id path and is only erased after typing its name back.
#
# Usage: scripts/prepare-windows-disk.sh DISK

set -euo pipefail

esp_size_mib=512
msr_size_mib=16

die() { echo "error: $*" >&2; exit 1; }

disk="${1:-}"
[[ -n "$disk" ]] || die "usage: $0 DISK"

if [[ -b "$disk" ]]; then
  [[ "$disk" == /dev/disk/by-id/* && "$disk" != *-part* ]] \
    || die "give a whole disk by its /dev/disk/by-id/ path (kernel names change between boots)"
  [[ $EUID -eq 0 ]] || die "run with sudo for a real disk"
  if lsblk -no MOUNTPOINTS "$disk" | grep -q .; then
    die "a partition on $disk is mounted; unmount it first"
  fi
  lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,LABEL "$disk"
  name="$(basename "$disk")"
  echo
  echo "This ERASES the whole disk above. Type its name to continue:"
  echo "  $name"
  read -r answer
  [[ "$answer" == "$name" ]] || die "name did not match; nothing changed"
elif [[ ! -f "$disk" ]]; then
  die "$disk is neither a block device nor an image file"
fi

sgdisk --zap-all "$disk" >/dev/null
sgdisk \
  -n "1:0:+${esp_size_mib}M" -t 1:ef00 -c "1:EFI system partition" \
  -n "2:0:+${msr_size_mib}M" -t 2:0c01 -c "2:Microsoft reserved partition" \
  "$disk" >/dev/null

esp_start=$(sgdisk -i 1 "$disk" | awk '/First sector/ {print $3}')
if [[ -b "$disk" ]]; then
  partprobe "$disk" 2>/dev/null || true
  udevadm settle
  mkfs.vfat -F 32 -s 8 -n SYSTEM "${disk}-part1" >/dev/null
else
  # Image file: write the filesystem in place at the partition's offset.
  mkfs.vfat -F 32 -s 8 -n SYSTEM --offset "$esp_start" "$disk" $((esp_size_mib * 1024)) >/dev/null
fi

sgdisk -p "$disk" | sed -n '/^Number/,$p'
echo "Prepared $disk: ESP (${esp_size_mib} MiB, FAT32) + MSR; remaining space left for Windows Setup."
