---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# Data drives mount by UUID at purpose-named paths

Data drives are mounted at purpose-named paths by UUID via the `mounts` role. Old paths in use while converging are retired from fstab without unmounting and become compatibility symlinks after the next boot.
