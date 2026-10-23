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

cd "$(dirname "${BASH_SOURCE[0]}")/../ansible"
host="$(hostname -s)"

if ! ansible-inventory --host "$host" >/dev/null 2>&1; then
  echo "Host '$host' is not in ansible/inventory/hosts.yml — add it before converging." >&2
  exit 1
fi

# Repo-local collections (see collections_path in ansible.cfg), so the root run
# uses exactly what was installed here.
ansible-galaxy collection install -r requirements.yml -p collections >/dev/null

if [[ $EUID -eq 0 ]]; then
  exec ansible-playbook site.yml --limit "$host" "$@"
else
  exec sudo ansible-playbook site.yml --limit "$host" "$@"
fi
