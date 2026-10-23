#!/usr/bin/env bash
# Disposable UEFI test VM (QEMU/KVM, no root needed) for exercising the
# fresh-install path: install Ubuntu from an ISO once, snapshot the clean
# install, run bootstrap.sh, and roll back to try again.
#
# Usage:
#   scripts/test-vm.sh create             create the disk, UEFI variable store and SSH key
#   scripts/test-vm.sh install ISO        boot the installer from ISO (window)
#   scripts/test-vm.sh run                boot the installed system (window, foreground)
#   scripts/test-vm.sh start              boot headless in the background
#   scripts/test-vm.sh stop               shut the guest down cleanly (over SSH) and wait
#   scripts/test-vm.sh ssh [CMD...]       SSH into the guest, or run CMD there
#   scripts/test-vm.sh wait-ssh           wait until the guest accepts SSH
#   scripts/test-vm.sh ssh-setup          print the one-time guest commands that enable SSH
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
#
# Settings (environment): VM_DIR, VM_NAME, VM_USER, VM_DISK_SIZE, VM_MEM, VM_CPUS, VM_SSH_PORT.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
name="${VM_NAME:-ms-test}"
vm_user="${VM_USER:-tester}"
ssh_port="${VM_SSH_PORT:-2222}"
dir="${VM_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/machine-setup/vm}/$name"
disk="$dir/disk.qcow2"
vars="$dir/OVMF_VARS.fd"
pidfile="$dir/qemu.pid"
ssh_key="$dir/ssh_key"
ovmf_code=/usr/share/OVMF/OVMF_CODE_4M.fd
ovmf_vars_template=/usr/share/OVMF/OVMF_VARS_4M.fd

die() { echo "error: $*" >&2; exit 1; }

is_running() { [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }
require_vm() { [[ -f "$disk" ]] || die "no VM at $dir — run: $0 create"; }
require_stopped() { ! is_running || die "VM is running; shut it down first"; }

# Dedicated key for this VM only; never used for anything else.
ensure_key() {
  [[ -f "$ssh_key" ]] || ssh-keygen -q -t ed25519 -N '' -C "machine-setup test VM ($name)" -f "$ssh_key"
}

# Read-only folder shared with the guest as 9p tag `vm-meta`: the public key and
# a one-time setup script (no private material).
ensure_share() {
  ensure_key
  mkdir -p "$dir/share"
  cp "$ssh_key.pub" "$dir/share/ssh_key.pub"
  cat >"$dir/share/setup-ssh.sh" <<'SETUP'
#!/usr/bin/env bash
# One-time test-VM setup: SSH server, the VM's dedicated key, passwordless sudo.
# Test VM only — never run this on a real machine.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo apt-get install -y openssh-server
install -d -m 700 "$HOME/.ssh"
touch "$HOME/.ssh/authorized_keys" && chmod 600 "$HOME/.ssh/authorized_keys"
grep -qxF "$(cat "$here/ssh_key.pub")" "$HOME/.ssh/authorized_keys" || cat "$here/ssh_key.pub" >>"$HOME/.ssh/authorized_keys"
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-test-vm >/dev/null
sudo chmod 440 /etc/sudoers.d/90-test-vm
echo "SSH test access enabled. Shut down and snapshot the VM."
SETUP
}

guest_ssh() {
  ensure_key
  ssh -i "$ssh_key" -p "$ssh_port" \
    -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile="$dir/known_hosts" -o ConnectTimeout=5 \
    "$vm_user@127.0.0.1" "$@"
}

boot() {
  require_vm
  ensure_share
  is_running && die "VM is already running (pid $(cat "$pidfile"))"
  qemu-system-x86_64 \
    -name "$name" \
    -machine q35,accel=kvm \
    -cpu host -smp "${VM_CPUS:-8}" -m "${VM_MEM:-16G}" \
    -drive if=pflash,format=raw,readonly=on,file="$ovmf_code" \
    -drive if=pflash,format=raw,file="$vars" \
    -drive file="$disk",if=virtio,format=qcow2,discard=unmap \
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:"$ssh_port"-:22 \
    -device virtio-vga -device qemu-xhci -device usb-tablet -device usb-kbd \
    -virtfs local,path="$repo_root",mount_tag=machine-setup,security_model=none,readonly=on \
    -virtfs local,path="$dir/share",mount_tag=vm-meta,security_model=none,readonly=on \
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
    ensure_key
    echo "Created $name at $dir"
    ;;
  install)
    iso="${1:-}"; [[ -f "$iso" ]] || die "usage: $0 install ISO"
    boot -display gtk -drive file="$iso",media=cdrom,readonly=on
    ;;
  run)
    boot -display gtk
    ;;
  start)
    boot -display none -daemonize
    echo "Started $name headless (SSH on 127.0.0.1:$ssh_port)"
    ;;
  stop)
    is_running || { echo "VM is not running"; exit 0; }
    guest_ssh sudo -n systemctl poweroff >/dev/null 2>&1 || true
    for _ in $(seq 1 60); do is_running || { echo "Stopped $name"; exit 0; }; sleep 2; done
    die "guest did not shut down within 2 minutes"
    ;;
  ssh)
    is_running || die "VM is not running"
    guest_ssh "$@"
    ;;
  wait-ssh)
    is_running || die "VM is not running"
    for _ in $(seq 1 90); do
      guest_ssh true 2>/dev/null && { echo "SSH ready"; exit 0; }
      sleep 2
    done
    die "guest did not accept SSH within 3 minutes"
    ;;
  ssh-setup)
    require_vm; ensure_share
    cat <<'EOF'
Boot the VM with `run`, then in a terminal inside the guest (as the test user):

  sudo mkdir -p /mnt/vm-meta && sudo mount -t 9p -o trans=virtio,ro vm-meta /mnt/vm-meta && bash /mnt/vm-meta/setup-ssh.sh

It installs an SSH server, authorises this VM's dedicated key, and gives the test
user passwordless sudo so tests can run unattended (test VM only). Then shut the
guest down and save a snapshot.
EOF
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
    qemu-img snapshot -U -l "$disk"
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
