#!/usr/bin/env bash
# Install media for the workstation: the stock Ubuntu desktop ISO plus linux/ (the
# autoinstall config and first-boot service). Repacked rather than copied onto a stick,
# because an ISO written to a stick is read-only, and this way a test VM boots exactly
# the image the real machine will.
#
# Usage:
#   scripts/build-install-media.sh build SOURCE_ISO OUTPUT_ISO
#       Asks for the login password; only its hash goes into OUTPUT_ISO, which stays out
#       of the repository (the repository is public). MACHINE_SETUP_PASSWORD_HASH replaces
#       the prompt; MACHINE_SETUP_TEST_HOOKS adds a directory of test hooks (test VMs).
#   sudo scripts/build-install-media.sh write OUTPUT_ISO /dev/disk/by-id/usb-...
#       Erases the stick, writes the image, and reads it back to verify. Only after
#       typing the stick's name back. An image file works too (tests).
#
# docs/linux-install.md has the procedure.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Kernel parameters for the installer itself, ahead of the `---` so the installer
# doesn't carry them into the installed system, where Ansible manages them
# (grub_cmdline_extra). The same NVMe setting applies while installing to those drives.
installer_params="nvme_core.default_ps_max_latency_us=0"

die() { echo "error: $*" >&2; exit 1; }

# SHA-512 crypt with raised rounds: libxcrypt verifies it, and it needs only openssl.
hash_password() {
  local password confirm salt
  read -rs -p "Login password for the new install: " password; echo >&2
  read -rs -p "Again: " confirm; echo >&2
  [[ "$password" == "$confirm" ]] || die "passwords did not match"
  (( ${#password} >= 12 )) || die "use at least 12 characters: the hash goes on the stick"
  salt="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | cut -c1-16)"
  printf '%s' "$password" | openssl passwd -6 -salt "rounds=1000000\$$salt" -stdin
}

build() {
  local source="${1:-}" output="${2:-}" hash config
  [[ -f "$source" && -n "$output" ]] || die "usage: $0 build SOURCE_ISO OUTPUT_ISO"
  [[ ! -e "$output" ]] || die "$output already exists"
  command -v xorriso >/dev/null || die "xorriso not found (apt install xorriso)"

  work="$(mktemp -d)"
  trap 'rm -rf -- "${work:?}"' EXIT
  chmod 700 "$work"
  xorriso -osirrox on -indev "$source" -extract /.disk/info "$work/info" \
    -extract /boot/grub/grub.cfg "$work/grub.cfg" -extract /md5sum.txt "$work/md5sum.txt" 2>/dev/null
  chmod u+w "$work"/*
  grep -q ' 26\.04' "$work/info" || die "$source is not an Ubuntu 26.04 image"

  hash="${MACHINE_SETUP_PASSWORD_HASH:-}"
  [[ -n "$hash" ]] || hash="$(hash_password)"
  [[ "$hash" == '$6$'* ]] || die "the password hash must be SHA-512 crypt"
  config="$(<"$repo_root/linux/autoinstall.yaml")"
  [[ "$config" == *@PASSWORD_HASH@* ]] || die "no password placeholder in linux/autoinstall.yaml"
  printf '%s\n' "${config//@PASSWORD_HASH@/"$hash"}" >"$work/autoinstall.yaml"

  sed -i "s| --- | $installer_params --- |" "$work/grub.cfg"
  grep -q "$installer_params ---" "$work/grub.cfg" || die "boot entries not found in grub.cfg"
  # Keep the image's own integrity check accurate for the file changed above.
  sed -i "s|^[0-9a-f]\{32\}  \./boot/grub/grub\.cfg$|$(md5sum <"$work/grub.cfg" | cut -d' ' -f1)  ./boot/grub/grub.cfg|" \
    "$work/md5sum.txt"

  local hooks=()
  if [[ -n "${MACHINE_SETUP_TEST_HOOKS:-}" ]]; then
    hooks=(-map "$MACHINE_SETUP_TEST_HOOKS" /machine-setup/test-hooks)
  fi
  if ! xorriso -indev "$source" -outdev "$output" -boot_image any replay \
      -map "$work/autoinstall.yaml" /autoinstall.yaml \
      -map "$repo_root/linux/machine-setup" /machine-setup \
      -map "$repo_root/bootstrap.sh" /machine-setup/bootstrap.sh \
      -map "$work/grub.cfg" /boot/grub/grub.cfg \
      -map "$work/md5sum.txt" /md5sum.txt \
      "${hooks[@]}" >"$work/xorriso.log" 2>&1; then
    cat "$work/xorriso.log" >&2
    die "xorriso failed"
  fi
  chmod 600 "$output"
  echo "Built $output"
}

# A stick that has booted holds a `writable` partition from the live session.
show_writable() {
  local disk="$1" part mnt
  for part in "$disk"-part*; do
    [[ -b "$part" && "$(lsblk -no LABEL "$part" | cat)" == writable ]] || continue
    mnt="$(mktemp -d)"
    if mount -o ro "$part" "$mnt" 2>/dev/null; then
      echo
      echo "The live session's 'writable' partition holds:"
      du -sh "$mnt"/* 2>/dev/null | cat
      umount "$mnt"
    fi
    rmdir "$mnt"
  done
}

write() {
  local image="${1:-}" disk="${2:-}" name answer size
  [[ -f "$image" && -n "$disk" ]] || die "usage: $0 write IMAGE DISK"
  if [[ -b "$disk" ]]; then
    [[ "$disk" == /dev/disk/by-id/usb-* && "$disk" != *-part* ]] \
      || die "give the whole stick by its /dev/disk/by-id/usb-... path"
    [[ $EUID -eq 0 ]] || die "run with sudo for a real disk"
    # Through cat: in a narrow terminal, lsblk (util-linux 2.39) prints forever.
    lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN,FSTYPE,LABEL,MOUNTPOINTS "$disk" | cat
    show_writable "$disk"
    name="$(basename "$disk")"
    echo
    echo "This ERASES the whole disk above. Type its name to continue:"
    echo "  $name"
    read -r answer
    [[ "$answer" == "$name" ]] || die "name did not match; nothing changed"
    local part
    for part in "$disk"-part*; do
      [[ -b "$part" ]] && umount "$part" 2>/dev/null || true
    done
    if lsblk -no MOUNTPOINTS "$disk" | grep -q .; then
      die "a partition on $disk is still mounted"
    fi
  elif [[ ! -f "$disk" ]]; then
    die "$disk is neither a block device nor an image file"
  fi

  size="$(stat -c %s "$image")"
  dd if="$image" of="$disk" bs=4M conv=fsync,notrunc status=progress
  sync
  [[ -b "$disk" ]] && blockdev --flushbufs "$disk"
  echo "Reading back to verify..."
  cmp -n "$size" "$image" "$disk" || die "the stick does not match the image"
  echo "Written and verified: $disk"
}

# Everything below runs inside main(), which bash parses completely before running:
# editing this file while a previous invocation is still running must not change what
# that invocation does next.
main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    build) build "$@" ;;
    write) write "$@" ;;
    *) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
}

main "$@"; exit
