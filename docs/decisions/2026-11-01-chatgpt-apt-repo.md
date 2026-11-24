---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-11-01-chatgpt-apt-repo; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# ChatGPT desktop app from OpenAI's apt repo

ChatGPT desktop app from OpenAI's apt repo, as a fresh install: none of its sessions or settings are restored. OpenAI publishes its signing key only inside the package, so the repository keeps a copy pinned by fingerprint (`key_file`). The package leaves an existing source in place, so the role installs the package's own source at handover (`vendor_source`); otherwise our bootstrap key would stay in use and a rotated key would break updates. Rejected: installing the `.deb` from the `latest` URL, which has no pin to verify it against.
