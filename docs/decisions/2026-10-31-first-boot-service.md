---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# First boot runs bootstrap.sh as root from a service

First boot runs `bootstrap.sh` as root for a named user, before the login screen, instead of granting temporary passwordless sudo, which would leave a privilege window and possibly a stale file after a failure. It runs from a service rather than the installer's chroot because Docker, snaps and mounts need a running system. A failure stays on screen until answered (retry or skip) and the service runs again at each boot, so a walk-away install can't end at a login screen hiding a half-configured machine.
