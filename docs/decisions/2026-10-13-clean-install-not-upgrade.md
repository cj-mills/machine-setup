---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-10-13-clean-install-not-upgrade; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# Move from 24.04 to 26.04 by clean install, not in-place upgrade

24.04 → 26.04 via **clean install** driven by this repo; in-place `do-release-upgrade` rejected (carries accumulated state, never exercises the fresh-install path).
