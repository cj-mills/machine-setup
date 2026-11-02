---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# What the /etc audit dropped, and what was already covered

Dropped from the `/etc` audit: the `bwrap` AppArmor profile (a failed experiment; `bwrap` runs on clean 26.04 without it), `fs.inotify.max_user_watches=524288` (the kernel scales this default with RAM, so on this machine the line should only lower it), and the NodeSource apt pins, which went with the repository. Covered already: the `lfs` filter in `/etc/gitconfig` comes from the `git-lfs` package, PIA writes its own routing tables, and there were no printers, polkit rules or sudoers changes.
