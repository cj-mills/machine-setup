---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# Fresh installs are tested in disposable QEMU/KVM VMs

Fresh-install testing uses a disposable QEMU/KVM VM (`scripts/test-vm.sh`, no root needed) with qcow2 snapshots: install once, snapshot, bootstrap, roll back. Inventory host `ms-test`.
