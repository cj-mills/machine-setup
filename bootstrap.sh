#!/usr/bin/env bash
# Bootstrap a fresh Debian-family machine from this repository.
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/cj-mills/machine-setup/main/bootstrap.sh)"
#
# 1. Installs the prerequisites (git, Ansible, chezmoi).
# 2. Clones this repository as the chezmoi source.
# 3. Converges the system layer (packages, repos, drivers) — needs no secrets.
# Then sign in to 1Password and run `chezmoi apply` for the user layer.
#
# Run it as your normal user; sudo is used where needed. An autoinstall's first boot
# has nobody to answer sudo, so linux/machine-setup/first-boot.sh runs it as root with
# MACHINE_SETUP_USER naming the user, who owns everything that belongs in a home.

set -euo pipefail

repo="${MACHINE_SETUP_REPO:-cj-mills/machine-setup}"

as_root() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }
as_user() {
  if [[ $EUID -eq 0 ]]; then
    runuser -u "$user" -- env HOME="$home" PATH="$bin_dir:$PATH" "$@"
  else
    "$@"
  fi
}

# Everything below runs inside main(), which bash parses completely before running:
# editing this file while a previous invocation is still running must not change what
# that invocation does next.
main() {
  user="$(id -un)"
  home="$HOME"
  if [[ $EUID -eq 0 ]]; then
    user="${MACHINE_SETUP_USER:-}"
    if [[ -z "$user" || "$user" == root ]]; then
      echo "Run as your normal user; sudo is used where needed." >&2
      exit 1
    fi
    home="$(getent passwd "$user" | cut -d: -f6)"
    export SUDO_USER="$user"  # the default for Ansible's primary_user
  fi
  bin_dir="$home/.local/bin"

  echo "==> Installing prerequisites"
  as_root apt-get update
  # --no-install-recommends: ansible-core otherwise pulls in the full `ansible`
  # collection bundle and WinRM/Kerberos libraries; collections come from
  # ansible/requirements.yml instead.
  as_root apt-get install -y --no-install-recommends git curl ansible-core python3-debian

  if ! as_user sh -c 'command -v chezmoi' >/dev/null 2>&1; then
    echo "==> Installing chezmoi to $bin_dir"
    as_user sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$bin_dir"
  fi
  export PATH="$bin_dir:$PATH"

  source_dir="$(as_user chezmoi source-path 2>/dev/null || true)"
  if [[ -n "$source_dir" && -d "$source_dir" ]]; then
    echo "==> Updating existing chezmoi source"
    as_user chezmoi git -- pull --ff-only
  else
    echo "==> Cloning $repo"
    as_user chezmoi init "$repo"
  fi
  tree="$(as_user git -C "$(as_user chezmoi source-path)" rev-parse --show-toplevel)"

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
}

main "$@"; exit
