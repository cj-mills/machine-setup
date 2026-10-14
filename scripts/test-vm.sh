#!/usr/bin/env bash
# Disposable UEFI test VM (QEMU/KVM, no root needed) for exercising the
# fresh-install path: install Ubuntu from an ISO once, snapshot the clean
# install, run bootstrap.sh, and roll back to try again.
#
# Usage:
#   scripts/test-vm.sh create             create the disk and UEFI variable store
#   scripts/test-vm.sh install ISO        boot the installer from ISO
#   scripts/test-vm.sh run                boot the installed system
#   scripts/test-vm.sh snapshot NAME      save a snapshot (VM must be off)
#   scripts/test-vm.sh restore NAME       roll back to a snapshot (VM must be off)
#   scripts/test-vm.sh list               list snapshots
#   scripts/test-vm.sh destroy            delete the VM
#
# Inside the guest, this repository is shared read-only over 9p, so local
# commits can be tested before they are pushed:
#   sudo mkdir -p /mnt/machine-setup
#   sudo mount -t 9p -o trans=virtio,version=9p2000.L,ro machine-setup /mnt/machine-setup
#   MACHINE_SETUP_REPO=file:///mnt/machine-setup bash /mnt/machine-setup/bootstrap.sh
# Guest SSH (once openssh-server is installed) is forwarded to 127.0.0.1:$VM_SSH_PORT.
#
# Settings (environment): VM_DIR, VM_NAME, VM_DISK_SIZE, VM_MEM, VM_CPUS, VM_SSH_PORT.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
name="${VM_NAME:-ms-test}"
dir="${VM_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/machine-setup/vm}/$name"
disk="$dir/disk.qcow2"
vars="$dir/OVMF_VARS.fd"
pidfile="$dir/qemu.pid"
ovmf_code=/usr/share/OVMF/OVMF_CODE_4M.fd
ovmf_vars_template=/usr/share/OVMF/OVMF_VARS_4M.fd

die() { echo "error: $*" >&2; exit 1; }

is_running() { [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }
require_vm() { [[ -f "$disk" ]] || die "no VM at $dir — run: $0 create"; }
require_stopped() { ! is_running || die "VM is running; shut it down first"; }

boot() {
  require_vm
  is_running && die "VM is already running (pid $(cat "$pidfile"))"
  qemu-system-x86_64 \
    -name "$name" \
    -machine q35,accel=kvm \
    -cpu host -smp "${VM_CPUS:-8}" -m "${VM_MEM:-16G}" \
    -drive if=pflash,format=raw,readonly=on,file="$ovmf_code" \
    -drive if=pflash,format=raw,file="$vars" \
    -drive file="$disk",if=virtio,format=qcow2,discard=unmap \
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:"${VM_SSH_PORT:-2222}"-:22 \
    -device virtio-vga -device virtio-tablet-pci -device virtio-keyboard-pci \
    -display gtk \
    -virtfs local,path="$repo_root",mount_tag=machine-setup,security_model=none,readonly=on \
    -pidfile "$pidfile" \
    "$@"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  create)
    [[ -e "$disk" ]] && die "VM already exists at $dir"
    [[ -r "$ovmf_code" && -r "$ovmf_vars_template" ]] || die "OVMF firmware not found (apt install ovmf)"
    [[ -w /dev/kvm ]] || die "/dev/kvm is not writable by $(id -un) (add yourself to the kvm group)"
    mkdir -p "$dir"
    qemu-img create -q -f qcow2 "$disk" "${VM_DISK_SIZE:-80G}"
    cp "$ovmf_vars_template" "$vars"
    echo "Created $name at $dir"
    ;;
  install)
    iso="${1:-}"; [[ -f "$iso" ]] || die "usage: $0 install ISO"
    boot -drive file="$iso",media=cdrom,readonly=on
    ;;
  run)
    boot
    ;;
  snapshot)
    snap="${1:-}"; [[ -n "$snap" ]] || die "usage: $0 snapshot NAME"
    require_vm; require_stopped
    qemu-img snapshot -c "$snap" "$disk"
    cp "$vars" "$dir/OVMF_VARS.$snap.fd"
    echo "Saved snapshot '$snap'"
    ;;
  restore)
    snap="${1:-}"; [[ -n "$snap" ]] || die "usage: $0 restore NAME"
    require_vm; require_stopped
    [[ -f "$dir/OVMF_VARS.$snap.fd" ]] || die "no snapshot named '$snap'"
    qemu-img snapshot -a "$snap" "$disk"
    cp "$dir/OVMF_VARS.$snap.fd" "$vars"
    echo "Restored snapshot '$snap'"
    ;;
  list)
    require_vm
    qemu-img snapshot -l "$disk"
    ;;
  destroy)
    require_vm; require_stopped
    rm -rf -- "$dir"
    echo "Deleted $name"
    ;;
  *)
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
