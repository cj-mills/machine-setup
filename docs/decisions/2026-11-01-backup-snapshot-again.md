---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-11-01-backup-snapshot-again; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# backup-snapshot --again takes a further snapshot the same day

`backup-snapshot --again` takes a further snapshot on the same day, as `YYYY-MM-DD-HHMMSS`. One-a-day stays the default so a timer catching up after boot adds nothing, but that made a pre-wipe run on a timer day a silent no-op.
