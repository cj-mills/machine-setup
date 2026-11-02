---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# Removed Windows apps stay removed by deleting their expedited-app workflows

Removed apps are kept removed by deleting the Windows Update orchestrator's "expedited apps" workflows for them (`UScheduler_Oobe`: CrossDeviceUpdate, DevHomeUpdate, OutlookUpdate, TFLUpdate = consumer Teams); EdgeUpdate, IA (Store business-critical updates) and LXP (language packs) stay. Deprovisioning alone didn't hold: in the VM, `usoclient CrossDeviceUpdate` reinstalled CrossDevice from the Store within 11 minutes of removal and again after a reboot (Store log `Acquisition;CrossDevice_UO-UsoClient`), and Dev Home likewise. With the workflows deleted, nothing came back over 2 hours including a reboot. Rejected: turning off Store automatic updates (`AutoDownload=2`), which would also stop updates to the apps that are kept.
