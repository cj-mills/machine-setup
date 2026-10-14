#!/usr/bin/env bash
# Converge this machine's system layer with Ansible. Idempotent: safe to re-run.
# Called by bootstrap.sh and by chezmoi whenever anything under ansible/ changes.
# Extra arguments pass through to ansible-playbook (e.g. --check --diff, --tags).

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../ansible"
host="$(hostname -s)"

if ! ansible-inventory --host "$host" >/dev/null 2>&1; then
  echo "Host '$host' is not in ansible/inventory/hosts.yml — add it before converging." >&2
  exit 1
fi

ansible-galaxy collection install -r requirements.yml >/dev/null
exec ansible-playbook site.yml --limit "$host" --ask-become-pass "$@"
