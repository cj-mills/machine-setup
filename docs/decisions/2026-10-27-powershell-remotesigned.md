---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# Windows PowerShell's execution policy is RemoteSigned

Windows PowerShell's execution policy is RemoteSigned (machine scope, a configuration unit): a fresh Windows is "Restricted", which blocks every script, PowerShell profiles included. The first `bootstrap.ps1` run bypasses the policy for its own process only (`powershell -ExecutionPolicy Bypass -File`), the same way `autounattend.xml` starts `first-logon.ps1`. Rejected: setting the policy in `first-logon.ps1`, which would split one setting between a script and the configuration. Found on the real install: the test VM's `desktop-run` had launched every command under its own Bypass; it now runs commands under the machine's policy.
