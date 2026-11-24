---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-10-13-qemu-test-vms; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# Fresh installs are tested in disposable QEMU/KVM VMs

Fresh-install testing uses a disposable QEMU/KVM VM (`scripts/test-vm.sh`, no root needed) with qcow2 snapshots: install once, snapshot, bootstrap, roll back. Inventory host `ms-test`.
