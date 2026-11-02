---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# Move from 24.04 to 26.04 by clean install, not in-place upgrade

24.04 → 26.04 via **clean install** driven by this repo; in-place `do-release-upgrade` rejected (carries accumulated state, never exercises the fresh-install path).
