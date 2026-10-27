#!/usr/bin/env bash
# Hide another drive's EFI system partitions from Windows Setup, and restore them.
#
# Windows Setup puts its boot files on an existing ESP when it finds one, even on a
# different drive than the one Windows is installed to (seen in the test VM: it used
# the decoy disk's ESP and created none on the Windows disk). Hiding every other ESP
# during installation makes Setup create its own on the Windows disk.
#
#   hide  retype each ESP (EF00) on DISK as a Linux filesystem partition (8300),
#         which Windows ignores, and rename it "hidden EFI system partition"
#   show  retype partitions named "hidden EFI system partition" back to EF00 and
#         restore the name "EFI system partition"
#
# Only partition-table metadata changes; the partitions' contents are untouched.
# While hidden, firmware may not boot from that ESP (e.g. the old OS on that drive).
#
# DISK is a disk image file (test VM) or a whole disk by its /dev/disk/by-id path.
#
# Usage: scripts/esp-visibility.sh hide|show DISK

set -euo pipefail

esp_type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
linux_type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
hidden_name="hidden EFI system partition"

die() { echo "error: $*" >&2; exit 1; }

# Everything below runs inside main(), which bash parses completely before running:
# editing this file while a previous invocation is still running (e.g. a VM in the
# foreground) must not change what that invocation does next.
main() {
  action="${1:-}"; disk="${2:-}"
  [[ "$action" == hide || "$action" == show ]] && [[ -n "$disk" ]] || die "usage: $0 hide|show DISK"

  if [[ -b "$disk" ]]; then
    [[ "$disk" == /dev/disk/by-id/* && "$disk" != *-part* ]] \
      || die "give a whole disk by its /dev/disk/by-id/ path (kernel names change between boots)"
    [[ $EUID -eq 0 ]] || die "run with sudo for a real disk"
  elif [[ ! -f "$disk" ]]; then
    die "$disk is neither a block device nor an image file"
  fi

  changed=0
  for n in $(sgdisk -p "$disk" | awk '/^ +[0-9]+ /{print $1}'); do
    info="$(sgdisk -i "$n" "$disk")"
    type="$(awk -F': ' '/Partition GUID code/ {print $2}' <<<"$info" | awk '{print $1}')"
    pname="$(awk -F"'" '/Partition name/ {print $2}' <<<"$info")"
    if [[ "$action" == hide && "$type" == "$esp_type" ]]; then
      sgdisk -t "$n:$linux_type" -c "$n:$hidden_name" "$disk" >/dev/null
      echo "Hid ESP: partition $n"
      changed=1
    elif [[ "$action" == show && "$pname" == "$hidden_name" && "$type" == "$linux_type" ]]; then
      sgdisk -t "$n:$esp_type" -c "$n:EFI system partition" "$disk" >/dev/null
      echo "Restored ESP: partition $n"
      changed=1
    fi
  done

  if [[ $changed == 0 ]]; then
    echo "Nothing to $action on $disk."
  elif [[ -b "$disk" ]]; then
    partprobe "$disk" 2>/dev/null || echo "(The kernel picks up the new partition types at the next boot.)"
  fi
  sgdisk -p "$disk" | sed -n '/^Number/,$p'
}

main "$@"; exit
