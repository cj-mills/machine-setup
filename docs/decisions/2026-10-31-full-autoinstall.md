---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# The Ubuntu install is a full autoinstall that stops at Ready to install

The Ubuntu install is a full autoinstall that stops at the desktop installer's Ready to install page, not an interactive storage section as first planned: the installer ignores `storage:` for an interactive section and offers its own screen, which can't express this layout (read from the 26.04.1 snap's subiquity and UI source). Without `autoinstall` on the kernel command line, that page shows the config itself and waits for Install, so the file opens by naming the drive it erases. The drive is matched by serial, so a machine without it stops with an error before that page; on the replica VM, a changed serial gave `matched no disk` and left all six disks byte-identical.
