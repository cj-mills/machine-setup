---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# The Windows AI stack is installed per project

Windows AI stack (Windows App SDK / Windows ML runtimes, Foundry Local) is installed per project, not in the base Windows setup: apps declare these runtimes as dependencies, and tutorials must document installing them, so a machine without them pre-installed matches what readers start from. A runtime moves into the base config once it's in daily use across projects.
