#!/usr/bin/env bash
# First boot after an autoinstall: run bootstrap.sh as root for the install's user,
# then reboot into the finished system (the NVIDIA driver needs it). Started by
# machine-setup-first-boot.service on tty1, before the login screen. On failure the
# message stays on screen until someone answers it, so a walk-away install can't end
# at a login screen that hides a half-configured machine.

set -uo pipefail

log=/var/log/machine-setup-first-boot.log
unit=machine-setup-first-boot.service

wait_for_network() {
  for _ in $(seq 1 60); do
    curl -fsS --max-time 5 -o /dev/null https://github.com && return 0
    sleep 5
  done
  echo "No connection to github.com."
  return 1
}

converge() {
  local user
  user="$(getent passwd 1000 | cut -d: -f1)"
  [[ -n "$user" ]] || { echo "No user with UID 1000."; return 1; }
  # Test VMs only: where to clone from (scripts/test-vm.sh).
  if [[ -f /etc/machine-setup/first-boot.env ]]; then
    set -a; . /etc/machine-setup/first-boot.env; set +a
  fi
  [[ "${MACHINE_SETUP_REPO:-}" == file://* ]] || wait_for_network || return 1
  MACHINE_SETUP_USER="$user" /usr/local/lib/machine-setup/bootstrap.sh || return 1
  # The first-login wizard asks nothing this setup needs. It takes two stamps: with only
  # the first, it treats the account as upgraded from an older release and runs anyway.
  runuser -u "$user" -- sh -c '. /etc/os-release
    mkdir -p "$0/.config/gnome-initial-setup"
    echo yes >"$0/.config/gnome-initial-setup-done"
    touch "$0/.config/gnome-initial-setup/upgrade-$VERSION_ID-done"' \
    "$(getent passwd "$user" | cut -d: -f6)"
}

# Everything below runs inside main(), which bash parses completely before running:
# editing this file while a previous invocation is still running must not change what
# that invocation does next.
main() {
  exec > >(tee -a "$log") 2>&1
  while true; do
    echo "==> machine-setup first boot, $(date). Log: $log"
    if converge; then
      systemctl disable "$unit"
      echo "==> First boot finished. Rebooting in 15 seconds."
      sleep 15
      systemctl reboot
      exit 0
    fi
    echo
    echo "==> First boot FAILED. Log: $log (other consoles: Ctrl+Alt+F3)"
    echo "    It runs again at the next boot."
    read -r -p "    Press Enter to retry, or type skip for the login screen: " answer
    [[ "$answer" == skip ]] && exit 1
  done
}

main "$@"; exit
