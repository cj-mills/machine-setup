---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# Windows work lives on a Dev Drive at P:

Windows work lives on a Dev Drive at `P:`, set up by `configuration.winget`: a 2 TB growable VHDX on `C:`, ReFS, created with `diskpart` because `New-VHD` needs Hyper-V. Windows doesn't re-attach a VHDX at boot (tested), so a startup task does, as SYSTEM, before sign-in. `P:` mirrors `/mnt/projects`, and a high letter can't collide with other volumes. pip, uv, npm and NuGet caches move there too. The letter is assigned last: on the real machine, a lettered but unformatted volume made Explorer offer to format it, leaving NTFS instead of a Dev Drive, which the VM couldn't show because nobody clicks there. The unit verifies the result and repairs an empty volume. Verified in the VM from a clean install: all 66 units, and `P:` returns after reboots with its letter, trust and data. Rejected: a partition, because `C:` must never be resized.
