---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-11-01-veracrypt-release-deb; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# VeraCrypt from the vendor's release .deb

VeraCrypt comes from the vendor's release `.deb` for Ubuntu 26.04 in `release_debs`, pinned by SHA-256 after checking the signed checksum list and the PGP key's fingerprint. There's no vendor apt repository, and a third-party PPA would add a trust root for an encryption tool.
