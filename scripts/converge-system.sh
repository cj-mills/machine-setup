#!/usr/bin/env bash
# Converge this machine's system layer with Ansible. Idempotent: safe to re-run.
# Called by bootstrap.sh and by chezmoi whenever anything under ansible/ changes.
# Extra arguments pass through to ansible-playbook (e.g. --check --diff, --tags).
#
# The playbook runs as root under a single interactive `sudo` rather than using
# Ansible's become password prompt: Ansible's sudo prompt detection doesn't
# recognise sudo-rs (Ubuntu's default sudo since 25.10), and running as root is
# also the context of an unattended install.

set -euo pipefail

# Everything below runs inside main(), which bash parses completely before running:
# editing this file while a previous invocation is still running must not change what
# that invocation does next.
main() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../ansible"
  host="$(hostname -s)"

  if ! ansible-inventory --host "$host" >/dev/null 2>&1; then
    echo "Host '$host' is not in ansible/inventory/hosts.yml — add it before converging." >&2
    exit 1
  fi

  # Repo-local collections (see collections_path in ansible.cfg), so the root run
  # uses exactly what was installed here. They stay the repository owner's: an
  # autoinstall's first boot runs this script as root, later converges as that user.
  owner="$(stat -c %U .)"
  as_owner=()
  if [[ $EUID -eq 0 && "$owner" != root ]]; then
    as_owner=(runuser -u "$owner" -- env HOME="$(getent passwd "$owner" | cut -d: -f6)")
  fi
  "${as_owner[@]}" ansible-galaxy collection install -r requirements.yml -p collections >/dev/null

  if [[ $EUID -eq 0 ]]; then
    exec ansible-playbook site.yml --limit "$host" "$@"
  else
    exec sudo ansible-playbook site.yml --limit "$host" "$@"
  fi
}

main "$@"; exit
