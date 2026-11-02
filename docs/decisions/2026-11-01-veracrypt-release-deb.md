---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# VeraCrypt from the vendor's release .deb

VeraCrypt comes from the vendor's release `.deb` for Ubuntu 26.04 in `release_debs`, pinned by SHA-256 after checking the signed checksum list and the PGP key's fingerprint. There's no vendor apt repository, and a third-party PPA would add a trust root for an encryption tool.
