---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# The Linux drive uses LVM with deliberate under-allocation

Linux drive uses LVM with deliberate under-allocation: ext4 grows online, shrinking needs a live USB, so free pool space serves both root growth and test-OS volumes. Rejected: plain partitions filling the drive, and unallocated space at the end of the drive.
