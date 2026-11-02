---
status: accepted
decided_by: agent, approved by user
source: session 2026-11-02-machine-setup-republish
---
# The machine's own facts are a private overlay, not part of this repository

**Decision.** Facts that identify the workstation itself (the serial of the drive the
autoinstall erases, the data drives' filesystem UUIDs, the replica VM's drive serials
and sizes) live in a private directory, `MACHINE_SETUP_PRIVATE`, which on the workstation
is kept with the owner's private notes. It holds `workstation.env`, sourced by
`scripts/build-install-media.sh` (which fills `@LINUX_DRIVE_SERIAL@` in
`linux/autoinstall.yaml`) and by `scripts/test-vm.sh` for the replica, and `inventory/`,
an Ansible inventory overlay whose `host_vars` hold `mounts_list`.
`scripts/converge-system.sh` adds the first overlay it finds: `MACHINE_SETUP_PRIVATE`,
the notes on the workstation, then `/etc/machine-setup/inventory`, a root-only copy that
install media leave for the first boot, when the drive holding the notes isn't mounted
yet. A host whose mounts come from the overlay sets `mounts_private: true`, and the
mounts role stops if the overlay wasn't found rather than converging without its drives.

**Why.** The repository is public, and the owner's rule is that the machine's own facts
are not kept here. The code needs a few of them, so they can't simply be left out.

**Rejected.** Keeping the real serials and UUIDs in the code: low sensitivity, but they
identify the hardware and break that rule. Mounting by filesystem label instead of UUID
(would supersede `2026-10-26-data-drive-mounts-by-uuid`, and labels aren't unique).
Ansible `--extra-vars` from a file (highest precedence, applies to every host).
