---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-10-13-public-repository; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# The repository is public

Repository is **public** (`cj-mills/machine-setup`): bootstrap is a single `curl` with no auth step. Secrets never enter the repo; raw snapshots stay git-ignored.
