---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-10-31-hwe-kernel-track; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# The workstation follows the HWE kernel track

The workstation follows the HWE kernel track (`linux-generic-hwe-26.04`, NVIDIA modules for that flavour), as today. The desktop image ships it, and autoinstall's `kernel` key can only add a kernel: with a GA pin the HWE metapackages stayed installed, so GRUB would have moved to a kernel without NVIDIA modules at the first HWE release.
