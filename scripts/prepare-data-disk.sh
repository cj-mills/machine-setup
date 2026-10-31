#!/usr/bin/env bash
# Erase a disk and make it one ext4 data filesystem, as docs/design.md describes: GPT
# type "Linux filesystem", no root reservation. The UUID is chosen in advance, so the
# mounts role's host_vars entry can exist before the disk is touched.
#
# The disk must be given by its /dev/disk/by-id path and is only erased after typing
# its name back.
#
# Usage: sudo scripts/prepare-data-disk.sh DISK LABEL UUID

set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

# Everything below runs inside main(), which bash parses completely before running:
# editing this file while a previous invocation is still running must not change what
# that invocation does next.
main() {
  local disk="${1:-}" label="${2:-}" uuid="${3:-}"
  [[ -n "$disk" && -n "$label" && -n "$uuid" ]] || die "usage: $0 DISK LABEL UUID"
  [[ -b "$disk" ]] || die "$disk is not a block device"
  [[ "$disk" == /dev/disk/by-id/* && "$disk" != *-part* ]] \
    || die "give a whole disk by its /dev/disk/by-id/ path (kernel names change between boots)"
  [[ $EUID -eq 0 ]] || die "run with sudo"
  if lsblk -no MOUNTPOINTS "$disk" | grep -q .; then
    die "a partition on $disk is mounted; unmount it first"
  fi

  lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,LABEL "$disk"
  local name answer part
  name="$(basename "$disk")"
  echo
  echo "This ERASES the whole disk above. Type its name to continue:"
  echo "  $name"
  read -r answer
  [[ "$answer" == "$name" ]] || die "name did not match; nothing changed"

  for part in "$disk"-part*; do [[ -b "$part" ]] && wipefs -a -q "$part"; done
  sgdisk --zap-all "$disk" >/dev/null
  sgdisk --new=1:0:0 --typecode=1:8300 --change-name="1:$label" "$disk" >/dev/null
  partprobe "$disk" 2>/dev/null || true
  udevadm settle

  part="$disk-part1"
  [[ -b "$part" ]] || die "$part did not appear"
  mkfs.ext4 -q -m 0 -L "$label" -U "$uuid" "$part"
  udevadm settle
  echo "Prepared $disk: one ext4 filesystem, label $label, UUID $uuid."
}

main "$@"; exit
