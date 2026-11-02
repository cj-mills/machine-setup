---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# test-vm.sh gains a workstation replica

`scripts/test-vm.sh` gains a workstation replica (`VM_OS=replica`) so the install is tested unchanged: Secure Boot firmware, the Linux drive at its real size and serial with the old install's partitions, the other internal drives with their real serials and filesystem UUIDs, and media on a stick-sized USB disk. Access for tests comes from hooks on the media, as for Windows, so the config itself is identical.
