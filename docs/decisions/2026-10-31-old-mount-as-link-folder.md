---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-10-31-old-mount-as-link-folder; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# /mnt/SN850X_8TB_EXT4 becomes a plain folder of links

`/mnt/SN850X_8TB_EXT4` becomes a plain folder of links on the clean install, replacing the bind mount of the whole projects drive there. Only three paths under it are still hard-coded (`Projects/GitHub/cj-mills`, `claude-code-scratchpads`, `Model_Cache`), and everything else on the drive has moved to its new layout, so exposing the drive at the old path would only hide stale references. A symlink shows programs the resolved path, which the bind mount was chosen to avoid; that matters only for a session started inside `cjm-era`, and those are finished.
