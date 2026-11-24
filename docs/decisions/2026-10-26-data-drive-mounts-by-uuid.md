---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-10-26-data-drive-mounts-by-uuid; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# Data drives mount by UUID at purpose-named paths

Data drives are mounted at purpose-named paths by UUID via the `mounts` role. Old paths in use while converging are retired from fstab without unmounting and become compatibility symlinks after the next boot.
