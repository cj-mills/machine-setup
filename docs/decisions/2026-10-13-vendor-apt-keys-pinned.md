---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# Vendor apt keys are pinned by fingerprint

Vendor apt keys are fingerprint-pinned: a served key that doesn't match fails the run for manual review. Vendor packages that write their own apt source are handled per vendor: VS Code is told not to via debconf; Chrome and 1Password ignore any such setting and overwrite the same filename, so they are `self_managed` — the verified definition bootstraps the first install and the vendor's file is left alone afterwards (no rewrite/overwrite cycle, and key rotation arrives through signed package updates). Found by the 26.04 VM idempotence run.
