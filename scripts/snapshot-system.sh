#!/usr/bin/env bash
# Read-only snapshot of a Linux desktop's installed software and user configuration.
#
# Captures what was installed and customised (packages, repos, snaps, flatpaks,
# language-level tools, GNOME settings, dotfile names, services, mounts) so it can
# be curated into the declarative setup. Never reads secret material: ~/.ssh and
# similar locations are listed by name only.
#
# Output contains personal data (paths, hostnames, account names) and is written
# under inventory/raw/, which is git-ignored. Curated results go elsewhere.
#
# Usage: scripts/snapshot-system.sh [output-dir]

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$repo_root/inventory/raw/$(hostname -s)-$(date +%F)}"
mkdir -p "$out"

# cap <file> <command...>: run a command, saving stdout+stderr; never abort the snapshot.
cap() {
  local file="$out/$1"; shift
  mkdir -p "$(dirname "$file")"
  {
    echo "# \$ $*"
    if command -v "$1" >/dev/null 2>&1; then
      "$@" 2>&1
    else
      echo "(not installed: $1)"
    fi
  } >"$file"
}

# --- system ----------------------------------------------------------------
cap system/os-release.txt cat /etc/os-release
cap system/uname.txt uname -a
cap system/desktop-session.txt bash -c 'echo "XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP"; echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"; echo "SHELL=$SHELL"'
cap system/lsblk.txt lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,UUID,MOUNTPOINTS
cap system/fstab.txt cat /etc/fstab
cap system/user-groups.txt id
cap system/enabled-system-units.txt systemctl list-unit-files --state=enabled --no-pager
cap system/enabled-user-units.txt systemctl --user list-unit-files --state=enabled --no-pager
cap system/crontab.txt crontab -l
cap system/gpu.txt nvidia-smi
cap system/locale.txt localectl status
cap system/timezone.txt timedatectl show

# --- apt -------------------------------------------------------------------
cap apt/manual-packages.txt apt-mark showmanual
# Explicit install/remove commands over the life of the system: the best signal
# for "what did I actually choose to install", versus base-image packages.
cap apt/history-commandlines.txt bash -c '
  for f in $(ls -tr /var/log/apt/history.log* 2>/dev/null); do
    zgrep -h -E "^(Start-Date|Commandline):" "$f"
  done'
cap apt/sources-files.txt bash -c 'ls -l /etc/apt/sources.list.d/ /etc/apt/keyrings/ /usr/share/keyrings/ 2>&1'
cap apt/sources-contents.txt bash -c '
  for f in /etc/apt/sources.list /etc/apt/sources.list.d/*; do
    [[ -f "$f" ]] || continue; echo "=== $f"; grep -v "^\s*#" "$f" | grep -v "^\s*$"
  done'
cap apt/held-packages.txt apt-mark showhold
cap apt/nvidia-cuda-packages.txt bash -c "dpkg -l | grep -E '^ii\s+(nvidia|cuda|libcudnn|libnvidia-container|nvidia-container|tensorrt|libnccl)' "

# --- other package managers -------------------------------------------------
cap snap/list.txt snap list
cap flatpak/apps.txt flatpak list --app --columns=application,origin,version
cap flatpak/remotes.txt flatpak remotes
cap tools/pipx.txt pipx list --short
cap tools/uv-tools.txt uv tool list
cap tools/pip-user.txt python3 -m pip list --user
cap tools/npm-global.txt npm ls -g --depth=0
cap tools/cargo.txt cargo install --list
cap tools/go-bin.txt bash -c 'ls -1 "${GOPATH:-$HOME/go}/bin" 2>&1'
cap tools/mise.txt mise ls
cap tools/conda-envs.txt conda env list
cap tools/docker.txt bash -c 'docker version --format "{{.Server.Version}}" 2>&1; docker info --format "{{json .Runtimes}}" 2>&1'
cap tools/vscode-extensions.txt code --list-extensions --show-versions

# Manually placed binaries, AppImages and /opt installs.
cap manual/local-bin.txt bash -c 'ls -la "$HOME/.local/bin" /usr/local/bin 2>&1'
cap manual/opt.txt ls -la /opt
cap manual/appimages.txt bash -c 'find "$HOME" -maxdepth 3 -iname "*.AppImage" 2>/dev/null'
cap manual/user-desktop-entries.txt bash -c 'ls -la "$HOME/.local/share/applications" 2>&1'
cap manual/user-fonts.txt bash -c 'ls -la "$HOME/.local/share/fonts" "$HOME/.fonts" 2>&1'

# --- desktop ---------------------------------------------------------------
# dconf only stores keys changed from their defaults, so the dump is already a diff.
cap gnome/dconf-dump.ini dconf dump /
cap gnome/extensions-enabled.txt gnome-extensions list --enabled
cap gnome/extensions-user-installed.txt gnome-extensions list --user
cap gnome/default-apps.txt bash -c 'cat "$HOME/.config/mimeapps.list" 2>&1'
cap gnome/autostart.txt bash -c 'ls -la "$HOME/.config/autostart" 2>&1'

# --- user configuration (names only, plus non-secret shell/git config) --------
cap home/home-entries.txt ls -lA "$HOME"
cap home/config-entries.txt ls -lA "$HOME/.config"
cap home/local-share-entries.txt ls -lA "$HOME/.local/share"
cap home/ssh-entries.txt bash -c 'ls -lA "$HOME/.ssh" 2>&1'   # names only, never contents
cap home/git-config.txt git config --global --list --show-origin
cap home/bashrc-vs-skel.diff diff -u /etc/skel/.bashrc "$HOME/.bashrc"
cap home/profile-vs-skel.diff diff -u /etc/skel/.profile "$HOME/.profile"

echo "Snapshot written to: $out"
