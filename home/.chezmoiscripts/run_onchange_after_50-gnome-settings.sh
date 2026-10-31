#!/usr/bin/env bash
# The deliberate GNOME settings, re-applied whenever this list changes. Only what's been
# chosen on purpose: app window state and notifications stay out, and dock favorites are
# pinned by hand. Needs a user session bus, so run chezmoi from a desktop terminal.
set -euo pipefail

if ! command -v dconf >/dev/null 2>&1; then exit 0; fi
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  echo "No session bus: re-run 'chezmoi apply' from a desktop terminal for GNOME settings." >&2
  exit 1
fi

dconf load / <<'SETTINGS'
[org/gnome/desktop/interface]
gtk-enable-primary-paste=false

[org/gnome/desktop/peripherals/keyboard]
numlock-state=true

[org/gnome/desktop/screensaver]
lock-delay=uint32 1800

[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/desktop/sound]
event-sounds=false

[org/gnome/nautilus/preferences]
default-folder-viewer='list-view'

[org/gnome/settings-daemon/plugins/color]
night-light-enabled=true
night-light-schedule-automatic=false
night-light-schedule-from=20.0

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'

[org/gnome/shell]
disabled-extensions=['tiling-assistant@ubuntu.com']
enabled-extensions=['gTile@vibou']

[org/gnome/shell/extensions/dash-to-dock]
dash-max-icon-size=44
dock-position='LEFT'
extend-height=true

[org/gnome/shell/extensions/ding]
show-home=false

[org/gtk/gtk4/settings/file-chooser]
show-type-column=true

[org/gtk/settings/file-chooser]
show-type-column=true
SETTINGS
