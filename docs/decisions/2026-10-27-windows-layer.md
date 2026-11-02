---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# The Windows layer: answer file, first-sign-in scripts, WinGet Configuration

Windows layer: `windows/autounattend.xml` (local admin account, no stored password, no automatic device encryption, interactive disk choice), `windows/machine-setup/` (first-sign-in ESP check, `bootstrap.ps1`, WinGet Configuration schema 0.2). Windows Setup puts its boot files on any visible ESP, even on another drive, so other drives' ESPs are hidden during installation (`scripts/esp-visibility.sh`); repairing that after installation by resizing C: broke booting in the VM and was rejected. Verified end to end in the test VM from a clean install: all 62 units applied, a second test pass reports every unit in its desired state, and Windows boots with the other drive absent or its ESP visible. Runbook: `docs/windows-install.md`.
