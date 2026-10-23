#!/usr/bin/env bash
# Bootstrap a fresh Debian-family machine from this repository.
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/cj-mills/machine-setup/main/bootstrap.sh)"
#
# 1. Installs the prerequisites (git, Ansible, chezmoi).
# 2. Clones this repository as the chezmoi source.
# 3. Converges the system layer (packages, repos, drivers) — needs no secrets.
# Then sign in to 1Password and run `chezmoi apply` for the user layer.

set -euo pipefail

repo="${MACHINE_SETUP_REPO:-cj-mills/machine-setup}"
bin_dir="$HOME/.local/bin"

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user; sudo is used where needed." >&2
  exit 1
fi

echo "==> Installing prerequisites"
sudo apt-get update
# --no-install-recommends: ansible-core otherwise pulls in the full `ansible`
# collection bundle and WinRM/Kerberos libraries; collections come from
# ansible/requirements.yml instead.
sudo apt-get install -y --no-install-recommends git curl ansible-core python3-debian

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "==> Installing chezmoi to $bin_dir"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$bin_dir"
fi
export PATH="$bin_dir:$PATH"

source_dir="$(chezmoi source-path 2>/dev/null || true)"
if [[ -n "$source_dir" && -d "$source_dir" ]]; then
  echo "==> Updating existing chezmoi source"
  chezmoi git -- pull --ff-only
else
  echo "==> Cloning $repo"
  chezmoi init "$repo"
fi
tree="$(git -C "$(chezmoi source-path)" rev-parse --show-toplevel)"

echo "==> Converging system layer"
"$tree/scripts/converge-system.sh"

cat <<'EOF'

System layer done. Remaining steps:
  1. Reboot if the NVIDIA driver was installed.
  2. Open 1Password, sign in, and enable Settings → Developer → "Integrate with 1Password CLI"
     and "Use the SSH agent".
  3. Run: ~/.local/bin/chezmoi apply
     (~/.local/bin joins PATH at your next login; after that, plain `chezmoi` works.)
EOF
