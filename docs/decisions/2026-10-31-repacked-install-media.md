---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-10-31-repacked-install-media; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# Install media is the stock ISO repacked with xorriso

Install media is the stock ISO repacked with `xorriso`, not a config copied onto a stick: a stick written from an ISO is read-only, and repacking means the test VM boots the same image as the real machine. The login password's hash is made at build time and stays out of the repository; the image holds a salted SHA-512 crypt hash with raised rounds, which a strong password makes safe to keep on a stick. Rejected: a NoCloud `CIDATA` volume, which needs a second volume and differs between the test and the real boot.
