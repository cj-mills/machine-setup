---
status: accepted
decided_by: user, on the agent's recommendation ("Yes, both", 2026-11-10)
source: session 2026-11-10-machine-setup-open-work-check-in
---
# Steam comes from Ubuntu's multiverse

**Decision.** The `steam` role, on hosts with `steam_enabled`, enables i386 as a foreign
architecture and installs `steam-installer` from Ubuntu's multiverse. On NVIDIA hosts the
`nvidia` role then installs the driver's 32-bit libraries (`libnvidia-gl-<branch>:i386`)
at exactly the installed 64-bit version. The Steam library lives on its own drive at
`/mnt/games`, mounted like the other data drives.

**Why.** Steam's client is 32-bit and needs 32-bit graphics drivers, udev rules for
controllers (`steam-devices`) and the host's GPU stack: the package policy's first tier,
distro packages for deep OS integration. The deciding point is the driver: with the deb,
the 32-bit NVIDIA libraries come from the same archive and branch as the 64-bit ones and
move with `nvidia_driver_branch`. The package itself only bootstraps; the client and its
runtime update themselves in the user's home, so the archive's older launcher version
doesn't matter. It asks no license question (checked in its debconf templates); the
Steam Subscriber Agreement is accepted in the client.

**Rejected.**
- Flathub's `com.valvesoftware.Steam`: needs no i386 on the host, but its NVIDIA
  libraries are a separate Flatpak extension that must match the host driver's exact
  version, so a driver update breaks games until the extension follows; and the sandbox
  needs an override to reach `/mnt/games`.
- Valve's own deb (`steam-launcher`, with its own apt source): a second source for what
  the archive already carries.
- Canonical's snap: snaps are the policy's last resort, and it is not supported by Valve.

**Cost.** i386 is enabled system-wide, which nothing else on the host needed.
