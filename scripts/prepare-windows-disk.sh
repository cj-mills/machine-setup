#!/usr/bin/env bash
# Wipe a disk to an empty GPT for a fresh Windows install, so Windows Setup sees one
# block of unallocated space and creates its own partitions there (ESP, MSR,
# Windows, recovery).
#
# Deliberately no pre-made ESP: Windows Setup (24H2+) creates its own ESP anyway,
# and with two ESPs on the target disk it fails to service the boot files
# ("Failed to get system partition", 0x80073B92), as found in the test VM.
# Keeping Windows' boot files off other drives is handled after installation by
# windows/machine-setup/ensure-own-esp.ps1.
#
# Works on a disk image file (test VM) or a whole disk. A whole disk must be given
# by its /dev/disk/by-id path and is only erased after typing its name back.
#
# Usage: scripts/prepare-windows-disk.sh DISK

set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

# Everything below runs inside main(), which bash parses completely before running:
# editing this file while a previous invocation is still running (e.g. a VM in the
# foreground) must not change what that invocation does next.
main() {
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
    # Clear filesystem signatures in existing partitions too, so nothing stale
    # (e.g. an old ESP) is recognised later.
    for part in "$disk"-part*; do [[ -b "$part" ]] && wipefs -a -q "$part"; done
  elif [[ ! -f "$disk" ]]; then
    die "$disk is neither a block device nor an image file"
  fi

  sgdisk --zap-all "$disk" >/dev/null
  sgdisk --clear "$disk" >/dev/null
  if [[ -b "$disk" ]]; then
    partprobe "$disk" 2>/dev/null || true
    udevadm settle
  fi

  echo "Prepared $disk: empty GPT; all space left for Windows Setup."
}

main "$@"; exit
