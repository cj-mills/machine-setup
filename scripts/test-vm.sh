#!/usr/bin/env bash
# Disposable UEFI test VMs (QEMU/KVM, no root needed) for exercising fresh installs:
# install an OS once, snapshot the clean install, run the setup, roll back, repeat.
#
# Usage:
#   scripts/test-vm.sh create             create the VM (disks, UEFI variables, SSH key)
#   scripts/test-vm.sh install MEDIA      boot the installer (window); MEDIA is an ISO, or
#                                         for Windows a USB-stick image (.qcow2/.img)
#   scripts/test-vm.sh run                boot the installed system (window, foreground)
#   scripts/test-vm.sh start              boot headless in the background
#   scripts/test-vm.sh stop               shut the guest down cleanly (over SSH) and wait
#   scripts/test-vm.sh ssh [CMD...]       SSH into the guest, or run CMD there
#   scripts/test-vm.sh wait-ssh           wait until the guest accepts SSH
#   scripts/test-vm.sh desktop-run CMD    Windows: run PowerShell CMD in the desktop session (elevated)
#   scripts/test-vm.sh ssh-setup          Linux: print the one-time guest commands that enable SSH
#   scripts/test-vm.sh snapshot NAME      save a snapshot (VM must be off)
#   scripts/test-vm.sh restore NAME       roll back to a snapshot (VM must be off)
#   scripts/test-vm.sh list               list snapshots
#   scripts/test-vm.sh data-disk SIZE     Linux: add a blank second disk
#                                         (guest: /dev/disk/by-id/virtio-ms-test-data)
#   scripts/test-vm.sh destroy            delete the VM
#
# Each VM records its OS at creation (VM_OS=linux, the default, or windows):
#
#   Linux:   the repository is shared read-only over 9p, so local commits can be
#            tested before they are pushed:
#              sudo mkdir -p /mnt/machine-setup
#              sudo mount -t 9p -o trans=virtio,version=9p2000.L,ro machine-setup /mnt/machine-setup
#              MACHINE_SETUP_REPO=file:///mnt/machine-setup bash /mnt/machine-setup/bootstrap.sh
#
#   Windows: Secure Boot firmware with Microsoft keys, a software TPM (swtpm), SATA
#            disks and an e1000e NIC (in-box drivers). The target disk is wiped by
#            scripts/prepare-windows-disk.sh, and a "decoy" disk with a Linux-style EFI
#            system partition is attached first, reproducing the workstation's
#            boot-file hazard. The install procedure hides it first
#            (scripts/esp-visibility.sh hide <vm dir>/decoy.raw); VM_DECOY=0 boots
#            without the decoy, proving Windows boots from its own disk. During `install`, windows/ is served as a read-only USB drive
#            (autounattend.xml + machine-setup\) plus a test-only hook enabling SSH
#            with this VM's dedicated key.
#
# Settings (environment): VM_NAME, VM_OS, VM_DIR, VM_USER, VM_DISK_SIZE, VM_MEM,
# VM_CPUS, VM_SSH_PORT, VM_DECOY.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
name="${VM_NAME:-ms-test}"
# The workstation keeps VMs on its data drive; other machines in the user's data directory.
vm_root="${XDG_DATA_HOME:-$HOME/.local/share}/machine-setup/vm"
[[ -d /mnt/data/vm ]] && vm_root=/mnt/data/vm
dir="${VM_DIR:-$vm_root}/$name"
os="$(cat "$dir/os" 2>/dev/null || echo "${VM_OS:-linux}")"
case "$os" in
  linux)   default_user=tester;   default_port=2222 ;;
  windows) default_user=innom-dt; default_port=2223 ;;
  *) echo "error: unknown VM_OS '$os' (linux or windows)" >&2; exit 1 ;;
esac
vm_user="${VM_USER:-$default_user}"
ssh_port="${VM_SSH_PORT:-$default_port}"
disk="$dir/disk.qcow2"
data_disk="$dir/data.qcow2"   # Linux: optional second disk, e.g. for the mounts role
decoy_disk="$dir/decoy.raw"   # Windows: disk with a Linux-style ESP, attached first (raw,
                              # so scripts/esp-visibility.sh can hide/show its ESP)
vars="$dir/OVMF_VARS.fd"
pidfile="$dir/qemu.pid"
ssh_key="$dir/ssh_key"

if [[ "$os" == windows ]]; then
  ovmf_code=/usr/share/OVMF/OVMF_CODE_4M.ms.fd
  ovmf_vars_template=/usr/share/OVMF/OVMF_VARS_4M.ms.fd
else
  ovmf_code=/usr/share/OVMF/OVMF_CODE_4M.fd
  ovmf_vars_template=/usr/share/OVMF/OVMF_VARS_4M.fd
fi

die() { echo "error: $*" >&2; exit 1; }

is_running() { [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }
require_vm() { [[ -f "$disk" ]] || die "no VM at $dir — run: $0 create"; }
require_stopped() { ! is_running || die "VM is running; shut it down first"; }

# Dedicated key for this VM only; never used for anything else.
ensure_key() {
  [[ -f "$ssh_key" ]] || ssh-keygen -q -t ed25519 -N '' -C "machine-setup test VM ($name)" -f "$ssh_key"
}

# Linux: read-only folder shared with the guest as 9p tag `vm-meta`: the public key
# and a one-time setup script (no private material).
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

# Windows: the answer media, rebuilt from windows/ at every install, plus a test-only
# hook (never on real installation media) enabling OpenSSH with this VM's key.
ensure_answer_media() {
  ensure_key
  rm -rf "$dir/answer"
  cp -r "$repo_root/windows" "$dir/answer"
  local hooks="$dir/answer/machine-setup/test-hooks"
  mkdir -p "$hooks"
  cp "$ssh_key.pub" "$hooks/ssh_key.pub"
  cat >"$hooks/10-enable-ssh.ps1" <<'HOOK'
# Test VM only: OpenSSH server with the VM's dedicated key, PowerShell as the shell.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' | Out-Null
Set-Service -Name sshd -StartupType Automatic
Start-Service -Name sshd
$keys = Join-Path $env:ProgramData 'ssh\administrators_authorized_keys'
Copy-Item -Path (Join-Path $here 'ssh_key.pub') -Destination $keys -Force
& icacls.exe $keys /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -PropertyType String -Force `
    -Value "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" | Out-Null
if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' `
        -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow | Out-Null
}
# The VM's NAT network is classified Public; the capability's rule may not cover it.
Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Profile Any -Enabled True
# Sign in at every boot, so desktop-run works after a reboot. The answer file's AutoLogon
# only covers the first boot, and the account's password is blank.
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty $winlogon AutoAdminLogon '1'
Set-ItemProperty $winlogon DefaultUserName $env:USERNAME
Set-ItemProperty $winlogon DefaultPassword ''
Remove-ItemProperty $winlogon AutoLogonCount -ErrorAction SilentlyContinue
Write-Output 'Test VM: SSH enabled.'
HOOK
}

# Windows: software TPM 2.0; exits when QEMU disconnects, state kept in $dir/tpm.
start_tpm() {
  mkdir -p "$dir/tpm"
  if [[ -f "$dir/swtpm.pid" ]]; then kill "$(cat "$dir/swtpm.pid")" 2>/dev/null || true; fi
  rm -f "$dir/swtpm.sock" "$dir/swtpm.pid"
  swtpm socket --tpm2 --tpmstate dir="$dir/tpm" \
    --ctrl type=unixio,path="$dir/swtpm.sock" \
    --pid file="$dir/swtpm.pid" --log file="$dir/swtpm.log" --terminate --daemon
  for _ in $(seq 1 50); do [[ -S "$dir/swtpm.sock" ]] && return 0; sleep 0.1; done
  die "swtpm did not start (see $dir/swtpm.log)"
}

boot_linux() {
  ensure_share
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
    $([[ -f "$data_disk" ]] && echo "-drive file=$data_disk,if=none,id=data,format=qcow2,discard=unmap -device virtio-blk-pci,drive=data,serial=ms-test-data") \
    "$@"
}

boot_windows() {
  start_tpm
  local decoy=()
  if [[ "${VM_DECOY:-1}" != 0 ]]; then
    decoy=(-drive file="$decoy_disk",if=none,id=decoy,format=raw
           -device ide-hd,drive=decoy,bus=ide.0)
  fi
  qemu-system-x86_64 \
    -name "$name" \
    -machine q35,smm=on,accel=kvm \
    -global driver=cfi.pflash01,property=secure,value=on \
    -cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time \
    -smp "${VM_CPUS:-8}" -m "${VM_MEM:-16G}" \
    -drive if=pflash,format=raw,unit=0,readonly=on,file="$ovmf_code" \
    -drive if=pflash,format=raw,unit=1,file="$vars" \
    -chardev socket,id=chrtpm,path="$dir/swtpm.sock" \
    -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-crb,tpmdev=tpm0 \
    "${decoy[@]}" \
    -drive file="$disk",if=none,id=sys,format=qcow2,discard=unmap \
    -device ide-hd,drive=sys,bus=ide.1 \
    -nic user,model=e1000e,hostfwd=tcp:127.0.0.1:"$ssh_port"-:22 \
    -vga std -device qemu-xhci -device usb-tablet -device usb-kbd \
    -pidfile "$pidfile" \
    "$@"
}

boot() {
  require_vm
  is_running && die "VM is already running (pid $(cat "$pidfile"))"
  if [[ "$os" == windows ]]; then boot_windows "$@"; else boot_linux "$@"; fi
}

# Windows guests have no `sudo`; shut down with the native command.
guest_poweroff() {
  if [[ "$os" == windows ]]; then guest_ssh 'shutdown.exe /s /t 0'
  else guest_ssh sudo -n systemctl poweroff; fi
}

# Windows: run a PowerShell command in the signed-in desktop session (elevated), via a
# one-off scheduled task, and print its output. SSH key sign-ins are non-interactive
# logons in which Store and app-package installs fail (e.g. `winget configure
# --enable` aborts with 0x80004004); the desktop session behaves like a person at
# the keyboard. The command runs as if typed at a fresh prompt: in its own
# powershell.exe under the machine's execution policy (the runner's own Bypass, which
# child processes would otherwise inherit, once hid a fresh Windows' "Restricted").
desktop_run() {
  local b64 timeout="${VM_DESKTOP_TIMEOUT:-14400}"
  b64="$(printf '%s' "$1" | base64 -w0)"
  guest_ssh "
\$ErrorActionPreference = 'Stop'
\$id = [guid]::NewGuid().ToString('n')
\$dir = 'C:\\machine-setup\\desktop-run'
New-Item -ItemType Directory -Force -Path \$dir | Out-Null
Set-Content -Path \"\$dir\\\$id.ps1\" -Encoding UTF8 -Value ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$b64')))
# Runner (fixed text; paths come in as parameters): always records an exit code,
# even if the command throws.
Set-Content -Path \"\$dir\\runner.ps1\" -Encoding UTF8 -Value @(
  'param([string] \$Payload, [string] \$Log, [string] \$Done)'
  '\$code = 1'
  'Remove-Item Env:PSExecutionPolicyPreference -ErrorAction SilentlyContinue'
  '# Exit code: the last native command''s, else 1 if the last statement failed.'
  '\$epilogue = ''\$ok = \$?; if (\$LASTEXITCODE) { exit \$LASTEXITCODE }; if (-not \$ok) { exit 1 }; exit 0'''
  '\$command = (Get-Content -Raw -Path \$Payload) + [Environment]::NewLine + \$epilogue'
  '\$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(\$command))'
  '# Stringify stderr lines, which Windows PowerShell would wrap as error records.'
  'try { & powershell.exe -NoProfile -EncodedCommand \$encoded 2>&1 | ForEach-Object { \"\$_\" } | Out-File -FilePath \$Log; \$code = \$LASTEXITCODE }'
  'catch { \"desktop-run: \$_\" | Out-File -Append -FilePath \$Log; \$code = 1 }'
  'finally { Set-Content -Path \$Done -Value \$code }'
)
# An Interactive-logon task only runs once the user's desktop session exists (e.g.
# right after boot, autologon may still be in progress).
\$sessionDeadline = (Get-Date).AddMinutes(10)
while (-not (Get-Process explorer -IncludeUserName -ErrorAction SilentlyContinue | Where-Object { \$_.UserName -like \"*\\\$env:USERNAME\" })) {
  if ((Get-Date) -gt \$sessionDeadline) { Write-Output 'desktop-run: no desktop session for this user after 10 minutes'; exit 125 }
  Start-Sleep -Seconds 5
}
\$task = \"machine-setup-\$id\"
Register-ScheduledTask -TaskName \$task -Force \`
  -Action (New-ScheduledTaskAction -Execute powershell.exe -Argument \"-NoProfile -ExecutionPolicy Bypass -File \$dir\\runner.ps1 -Payload \$dir\\\$id.ps1 -Log \$dir\\\$id.log -Done \$dir\\\$id.done\") \`
  -Principal (New-ScheduledTaskPrincipal -UserId \$env:USERNAME -LogonType Interactive -RunLevel Highest) | Out-Null
Start-ScheduledTask -TaskName \$task
\$deadline = (Get-Date).AddSeconds($timeout)
while (-not (Test-Path \"\$dir\\\$id.done\") -and (Get-Date) -lt \$deadline) { Start-Sleep -Seconds 5 }
Unregister-ScheduledTask -TaskName \$task -Confirm:\$false
Get-Content \"\$dir\\\$id.log\" -ErrorAction SilentlyContinue
if (-not (Test-Path \"\$dir\\\$id.done\")) { Write-Output 'desktop-run: timed out after $timeout s'; exit 124 }
\$code = [int](Get-Content \"\$dir\\\$id.done\")
Write-Output \"desktop-run exit code: \$code\"
exit \$code
"
}

guest_ssh() {
  ensure_key
  ssh -i "$ssh_key" -p "$ssh_port" \
    -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile="$dir/known_hosts" -o ConnectTimeout=5 \
    "$vm_user@127.0.0.1" "$@"
}

# Everything below runs inside main(), which bash parses completely before running:
# editing this file while a previous invocation is still running (e.g. a VM in the
# foreground) must not change what that invocation does next.
main() {
  cmd="${1:-}"; shift || true
  case "$cmd" in
    create)
      [[ -e "$disk" ]] && die "VM already exists at $dir"
      [[ -r "$ovmf_code" && -r "$ovmf_vars_template" ]] || die "OVMF firmware not found (apt install ovmf)"
      [[ -w /dev/kvm ]] || die "/dev/kvm is not writable by $(id -un) (add yourself to the kvm group)"
      mkdir -p "$dir"
      if [[ "$os" == windows ]]; then
        command -v swtpm >/dev/null || die "swtpm not found (apt install swtpm swtpm-tools)"
        # Target disk, laid out exactly as the real Windows drive will be.
        truncate -s "${VM_DISK_SIZE:-128G}" "$dir/disk.raw"
        "$repo_root/scripts/prepare-windows-disk.sh" "$dir/disk.raw" >/dev/null
        qemu-img convert -q -O qcow2 "$dir/disk.raw" "$disk" && rm -f "$dir/disk.raw"
        # Decoy: a Linux-style drive whose ESP Windows Setup may try to use.
        truncate -s 2G "$decoy_disk"
        sgdisk -n 1:0:+512M -t 1:ef00 -c "1:EFI system partition" -n 2:0:0 -t 2:8300 "$decoy_disk" >/dev/null
        mkfs.vfat -F 32 -s 8 -n ESP --offset "$(sgdisk -i 1 "$decoy_disk" | awk '/First sector/ {print $3}')" \
          "$decoy_disk" $((512 * 1024)) >/dev/null
      else
        qemu-img create -q -f qcow2 "$disk" "${VM_DISK_SIZE:-80G}"
      fi
      cp "$ovmf_vars_template" "$vars"
      echo "$os" >"$dir/os"
      ensure_key
      echo "Created $os VM $name at $dir"
      ;;
    install)
      media="${1:-}"; [[ -f "$media" ]] || die "usage: $0 install MEDIA"
      if [[ "$os" == windows ]]; then
        ensure_answer_media
        case "$media" in
          *.iso) installer=(-drive file="$media",media=cdrom,readonly=on) ;;
          *) # USB-stick image; guest writes go to a throwaway overlay. No bootindex:
             # the firmware's own boot order applies, as on real hardware, so after
             # Setup's first reboot the new Windows Boot Manager entry wins and the
             # installer isn't booted a second time.
             installer=(-drive file="$media",if=none,id=installer,snapshot=on
                        -device usb-storage,drive=installer,removable=on) ;;
        esac
        boot -display gtk "${installer[@]}" \
          -drive file=fat:16:"$dir/answer",if=none,id=answer,format=raw,readonly=on \
          -device usb-storage,drive=answer,removable=on
      else
        boot -display gtk -drive file="$media",media=cdrom,readonly=on
      fi
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
      guest_poweroff >/dev/null 2>&1 || true
      for _ in $(seq 1 90); do is_running || { echo "Stopped $name"; exit 0; }; sleep 2; done
      die "guest did not shut down within 3 minutes"
      ;;
    ssh)
      is_running || die "VM is not running"
      guest_ssh "$@"
      ;;
    desktop-run)
      [[ "$os" == windows ]] || die "desktop-run is for Windows VMs"
      is_running || die "VM is not running"
      [[ -n "${1:-}" ]] || die "usage: $0 desktop-run 'POWERSHELL COMMAND'"
      desktop_run "$1"
      ;;
    wait-ssh)
      is_running || die "VM is not running"
      for _ in $(seq 1 150); do
        guest_ssh exit 0 2>/dev/null && { echo "SSH ready"; exit 0; }
        sleep 2
      done
      die "guest did not accept SSH within 5 minutes"
      ;;
    ssh-setup)
      require_vm
      [[ "$os" == linux ]] || die "Windows VMs enable SSH automatically during install (test hook)"
      ensure_share
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
      if [[ -d "$dir/tpm" ]]; then rm -rf "$dir/tpm.$snap"; cp -r "$dir/tpm" "$dir/tpm.$snap"; fi
      echo "Saved snapshot '$snap'"
      ;;
    restore)
      snap="${1:-}"; [[ -n "$snap" ]] || die "usage: $0 restore NAME"
      require_vm; require_stopped
      [[ -f "$dir/OVMF_VARS.$snap.fd" ]] || die "no snapshot named '$snap'"
      qemu-img snapshot -a "$snap" "$disk"
      cp "$dir/OVMF_VARS.$snap.fd" "$vars"
      if [[ -d "$dir/tpm.$snap" ]]; then rm -rf "$dir/tpm"; cp -r "$dir/tpm.$snap" "$dir/tpm"; fi
      echo "Restored snapshot '$snap'"
      ;;
    list)
      require_vm
      qemu-img snapshot -U -l "$disk"
      ;;
    data-disk)
      size="${1:-}"; [[ -n "$size" ]] || die "usage: $0 data-disk SIZE (e.g. 10G)"
      [[ "$os" == linux ]] || die "data-disk is for Linux VMs"
      require_vm; require_stopped
      rm -f "$data_disk"
      qemu-img create -q -f qcow2 "$data_disk" "$size"
      echo "Attached blank $size data disk (guest: /dev/disk/by-id/virtio-ms-test-data); replaces any previous one"
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
}

main "$@"; exit
