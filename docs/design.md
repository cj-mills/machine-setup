# machine-setup — design

Declarative, re-runnable setup for every machine I work on: the primary Ubuntu
workstation, OS test installs, Jetson and Raspberry Pi deployment targets, and
(later) Windows. The same code handles a fresh install and ongoing maintenance:
it converges a machine to the described state rather than running one-shot steps.

## Targets

| Group | Machine(s) | OS | Arch | Managed how |
|---|---|---|---|---|
| `workstation` | Primary desktop (RTX 4090) | Ubuntu 26.04 LTS | x86_64 | Locally (Ansible `-c local` + chezmoi) |
| `testbed` | An LVM test-OS volume on the Linux drive (shared ESP), not yet created | Rotating — NixOS first | x86_64 | Per-OS; chezmoi dotfiles carry over |
| `jetson` | Jetson Orin Nano | JetPack (Ubuntu-based L4T) | arm64 | Ansible over SSH from the workstation |
| `rpi` | Raspberry Pi + Hailo-8L AI Kit | Raspberry Pi OS (Debian) | arm64 | Ansible over SSH from the workstation |
| `windows` | Dual-boot Windows install | Windows 11 | x86_64 | chezmoi + WinGet Configuration (later phase) |

Ubuntu LTS stays the primary workstation OS: CUDA, JetPack, Isaac, ROS 2, Unity
and Hailo tooling all target Ubuntu/Debian first. Other distros are exploration
on the test partition, not daily drivers.

## Layers and tools

| Layer | Scope | Tool |
|---|---|---|
| 0. OS install | Partitioning, base install, first user | Ubuntu autoinstall (`linux/`, confirmed on the installer's Ready to install page); L4T flash scripts; Pi image customisation; `autounattend.xml` (Windows, later) |
| 1. System | Packages, repos, drivers, services, mounts, groups, system settings | Ansible |
| 2. User | Dotfiles, shell, editor/terminal config, GNOME settings, secrets rendering | chezmoi |
| 3. Bootstrap | Bare install → tools above runnable | `bootstrap.sh` (`bootstrap.ps1` for Windows) — the only imperative entry point |

chezmoi is the day-to-day entry point: a `run_onchange_` script re-runs the
Ansible playbook whenever it changes, so `chezmoi update` converges both layers.

## Package source policy

Defaults, in order of preference; exceptions are recorded as decisions.

1. **Distro packages** — system libraries, drivers, core CLI tools, deep OS integration.
2. **Vendor apt repos** — where upstream maintains one (Docker, VS Code, 1Password, browsers, GitHub CLI). Managed as deb822 sources with `signed-by` keyrings.
3. **Flatpak (Flathub)** — GUI desktop apps; portable across distros.
4. **Per-user tool managers** — language runtimes and dev CLIs (mise, uv, Miniforge).
5. **Containers** — project stacks (see below).
6. **Snap** — only where it is the sole or clearly best option.

## Containers-first for project stacks

The host provides drivers, the container runtime and desktop apps. Project
stacks — CUDA toolkit versions, ROS 2, Isaac, COLMAP-style native builds,
model-serving — live in containers or per-project environments (conda/uv).

Reason: the device fleet spans Ubuntu 22.04 (JetPack 6), 26.04 and Debian, and
ROS 2 / Isaac releases are tied to specific Ubuntu versions. Host-installed
stacks drift and conflict; containers keep projects (and tutorials) reproducible
regardless of host.

Workstation consequence: no host CUDA toolkit by default; Docker (upstream repo)
plus NVIDIA Container Toolkit; conda environments are owned by their projects and
recreated from them, not by this repo.

## Secrets

1Password is the single source. No secret is committed or left in plaintext on disk.

- Desktop app + `op` CLI on interactive machines.
- **1Password SSH agent** for SSH keys and git commit signing.
- chezmoi renders secret-bearing config at apply time (`onepasswordRead`); tools that accept env vars get them via `op run`.
- Headless devices (Jetson, Pi) use a **1Password service account** scoped to a single vault.

## Workstation install flow

Front-load all human input, then walk away.

Order: Windows is reinstalled on its own drive first, so the Linux drive can then be
wiped whole.

1. Back up whatever in `~` isn't reproducible, then take a final `backup-snapshot`. Re-run `scripts/snapshot-system.sh` for a final inventory.
2. Boot the 26.04 installer from media built by `scripts/build-install-media.sh`. Its storage section targets the Linux drive by serial and lays out the ESP and LVM pool; pressing Install on the page that shows this config is the only interactive step, and on a machine without that serial the installer stops before it.
3. Unattended: OS install → first boot → a service runs bootstrap as root, before the login screen, for the Ansible system layer including data-drive mounts (no secrets needed) → reboot into the finished system.
4. Enable the SSH agent and CLI integration in the 1Password app and sign in, then run `chezmoi apply` from a desktop terminal for the user layer.

Runbook: `docs/linux-install.md`. Rehearsed on the replica VM before running on hardware.

## Drive layout (workstation)

One OS per physical drive; data drives mounted by filesystem UUID at purpose-named
paths, so paths survive a drive replacement. Drives are addressed in commands by
`/dev/disk/by-id/…` (serial-based): kernel `nvmeN` names change between boots.

The workstation's drive inventory is kept with the owner's private workspace notes,
outside this repository, and so are the facts the code needs: the Linux drive's serial
and the data drives' UUIDs. They live in a private directory (`MACHINE_SETUP_PRIVATE`;
on the workstation, in the hub) holding `workstation.env`, read by
`scripts/build-install-media.sh` and the replica VM, and `inventory/`, an Ansible
inventory overlay that `scripts/converge-system.sh` adds to `ansible/inventory/`. Install
media carry a copy of the overlay to `/etc/machine-setup/inventory`, for the first boot,
before the hub's drive is mounted
(`docs/decisions/2026-11-02-machine-facts-outside-repo.md`).

Data-drive filesystems use no root reservation (`-m 0`) and GPT type "Linux
filesystem" (`scripts/prepare-data-disk.sh`). Mounts are managed by the `mounts` role
from `mounts_list`, which for the workstation comes from the private overlay.

## Content layout (workstation)

Content is sorted by how it behaves, which also decides what gets backed up. The layout
itself is kept with the owner's private workspace notes, as is what `backup-snapshot`
copies: it reads `~/.config/backup-snapshot/`, which chezmoi links there on the
workstation (`docs/decisions/2026-11-02-backup-policy-in-config.md`).

On Windows, `C:` keeps apps, game libraries and default user folders, and a Dev Drive at
`P:` holds work, using the same names as Linux: `P:\cj-mills`, `P:\upstream`, `P:\scratch`,
plus `P:\caches`. It is a growable VHDX on `C:`, so BitLocker covers it and `C:` is never
resized.

The Qt tools from the cjm-substrate era keep working from `archive/cjm-era` through
compatibility links at their old paths, because their conda environment's editable
installs and scripts hard-code `/mnt/SN850X_8TB_EXT4/Projects/GitHub/cj-mills`. Editing
those would be rework on retired code; the links go when the era's tools do.
`/mnt/SN850X_8TB_EXT4` is a plain folder holding only such links (`mounts_links`).
`~/.cache/huggingface` is a chezmoi link to the model cache on `/mnt/data`.

## Decisions

One file per decision in `docs/decisions/`, named `YYYY-MM-DD-<slug>.md`. A decision is
never rewritten: a later one replaces it, and the old file's `status` becomes
`superseded`, with `superseded_by` naming its replacement. Decisions up to 2026-11-01
were converted verbatim from the table that used to be here.

## Repository layout

```
bootstrap.sh                  fresh-machine entry point (curl | bash)
scripts/converge-system.sh    run the Ansible system layer for this host
scripts/snapshot-system.sh    read-only inventory of a running system
scripts/test-vm.sh            disposable UEFI test VMs (Linux and Windows) for the fresh-install path
scripts/prepare-windows-disk.sh, esp-visibility.sh   Windows drive preparation (docs/windows-install.md)
scripts/build-install-media.sh   Ubuntu install media from the stock ISO (docs/linux-install.md)
linux/                        Ubuntu layer: autoinstall config, first-boot service
windows/                      Windows layer: answer file, first-sign-in scripts, WinGet Configuration
ansible/                      system layer: site.yml, inventory/, roles/
home/                         chezmoi source (.chezmoiroot), i.e. the user layer
  .chezmoiscripts/            hooks: re-converge on ansible/ change, `mise install` on mise config change
inventory/raw/                read-only system snapshots (git-ignored: personal data)
docs/                         design and decisions
```
