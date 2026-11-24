---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-10-27-windows-ai-stack-per-project; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# The Windows AI stack is installed per project

Windows AI stack (Windows App SDK / Windows ML runtimes, Foundry Local) is installed per project, not in the base Windows setup: apps declare these runtimes as dependencies, and tutorials must document installing them, so a machine without them pre-installed matches what readers start from. A runtime moves into the base config once it's in daily use across projects.
