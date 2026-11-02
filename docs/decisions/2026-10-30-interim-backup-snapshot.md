---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# Interim backup: weekly rsync snapshots to /mnt/backup

Interim backup: `backup-snapshot`, a weekly user timer writing dated `rsync --link-dest` snapshots to `/mnt/backup`, keeping the last 8. History is why it isn't a mirror, which would copy an accidental deletion over the backup at the next run. Snapshots are plain folders, so restoring needs no tool, and unchanged files take no extra space. It covers what the content layout marks as backed up. Rejected for now: restic or borg, which add a restore tool and a repository format for a stopgap.
