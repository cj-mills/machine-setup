---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-10-26-linux-lvm-under-allocated; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# The Linux drive uses LVM with deliberate under-allocation

Linux drive uses LVM with deliberate under-allocation: ext4 grows online, shrinking needs a live USB, so free pool space serves both root growth and test-OS volumes. Rejected: plain partitions filling the drive, and unallocated space at the end of the drive.
