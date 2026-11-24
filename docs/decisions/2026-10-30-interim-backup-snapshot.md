---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-10-30-interim-backup-snapshot; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# Interim backup: weekly rsync snapshots to /mnt/backup

Interim backup: `backup-snapshot`, a weekly user timer writing dated `rsync --link-dest` snapshots to `/mnt/backup`, keeping the last 8. History is why it isn't a mirror, which would copy an accidental deletion over the backup at the next run. Snapshots are plain folders, so restoring needs no tool, and unchanged files take no extra space. It covers what the content layout marks as backed up. Rejected for now: restic or borg, which add a restore tool and a repository format for a stopgap.
