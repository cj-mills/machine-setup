# machine-setup — design

Declarative, re-runnable setup for every machine I work on: the primary Ubuntu
workstation, OS test installs, Jetson and Raspberry Pi deployment targets, and
(later) Windows. The same code handles a fresh install and ongoing maintenance:
it converges a machine to the described state rather than running one-shot steps.

## Targets

| Group | Machine(s) | OS | Arch | Managed how |
|---|---|---|---|---|
| `workstation` | Primary desktop (RTX 4090) | Ubuntu 26.04 LTS | x86_64 | Locally (Ansible `-c local` + chezmoi) |
| `testbed` | Today `nvme1n1p9`, disposable; after the clean install, an LVM test-OS volume on the Linux drive (shared ESP) | Rotating — NixOS first | x86_64 | Per-OS; chezmoi dotfiles carry over |
| `jetson` | Jetson Orin Nano | JetPack (Ubuntu-based L4T) | arm64 | Ansible over SSH from the workstation |
| `rpi` | Raspberry Pi + Hailo-8L AI Kit | Raspberry Pi OS (Debian) | arm64 | Ansible over SSH from the workstation |
| `windows` | Dual-boot Windows install | Windows 11 | x86_64 | chezmoi + WinGet Configuration (later phase) |

Ubuntu LTS stays the primary workstation OS: CUDA, JetPack, Isaac, ROS 2, Unity
and Hailo tooling all target Ubuntu/Debian first. Other distros are exploration
on the test partition, not daily drivers.

## Layers and tools

| Layer | Scope | Tool |
|---|---|---|
| 0. OS install | Partitioning, base install, first user | Ubuntu autoinstall (storage section interactive); L4T flash scripts; Pi image customisation; `autounattend.xml` (Windows, later) |
| 1. System | Packages, repos, drivers, services, mounts, groups, system settings | Ansible |
| 2. User | Dotfiles, shell, editor/terminal config, GNOME settings, secrets rendering | chezmoi |
| 3. Bootstrap | Bare install → tools above runnable | `bootstrap.sh` (`bootstrap.ps1` for Windows) — the only imperative entry point |

chezmoi is the day-to-day entry point: a `run_onchange_` script re-runs the
Ansible playbook whenever it changes, so `chezmoi update` converges both layers.

## Package source policy

Defaults, in order of preference; exceptions are recorded per item in the inventory review.

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

1. Back up `~` state (`~/.claude`, `~/.cjm`, shell history, anything not reproducible). Re-run `scripts/snapshot-system.sh` for a final inventory.
2. Boot the 26.04 installer with the autoinstall config. Its storage section targets the Linux drive by serial and lays out the ESP and LVM pool from the drive-layout table; confirming that target is the only interactive step.
3. Unattended: OS install → first boot → bootstrap runs the Ansible system layer, including data-drive mounts (no secrets needed).
4. Sign in to 1Password, then `chezmoi apply` for the user layer.

Validated in a 26.04 VM before running on hardware.

## Drive layout (workstation)

One OS per physical drive; data drives mounted by filesystem UUID at purpose-named
paths, so paths survive a drive replacement. Drives are addressed in commands by
`/dev/disk/by-id/…` (serial-based): kernel `nvmeN` names change between boots.

| Drive (serial) | Role | Mount | Filesystem |
|---|---|---|---|
| Samsung 990 PRO 4TB (…123428Y) | Linux only: 2 GB ESP (shared with test OSes), LVM pool — root ~2.5 TB, swap 64 GB, ~1 TB unallocated for growth and test-OS volumes | `/` | ext4 on LVM |
| Samsung 990 PRO 4TB (…701402T) | Windows only (fresh install, own ESP) | — | NTFS |
| WD SN850X 8TB (…0960) | Projects | `/mnt/projects` (alias `/mnt/SN850X_8TB_EXT4`) | ext4 |
| WD SN850X 8TB (…0499) | Datasets, model weights, media | `/mnt/data` | ext4 |
| Samsung 860 EVO 2TB | Linux Steam library (Windows keeps its own) | `/mnt/games` | ext4 (to convert) |
| Crucial BX500 2TB #1 | Cold storage | `/mnt/archive` | ext4 |
| Crucial BX500 2TB #2 (…A5C8) | Backup target | `/mnt/backup` | ext4 |
| Intel 660p 512GB | Jetson Orin Nano internal NVMe boot drive | — | JetPack |
| Samsung 850 EVO 500GB (USB) | Raspberry Pi 5 boot drive | — | Pi OS |
| Samsung 980 1TB (USB) | Transfers between machines/OSes | removable | exFAT |

Data-drive filesystems use no root reservation (`-m 0`) and GPT type "Linux
filesystem" (`scripts/prepare-data-disk.sh`). Mounts are managed by the `mounts` role
from `host_vars`.

## Content layout (workstation)

Content is sorted by how it behaves, which also decides what gets backed up.

| Path | Holds | Backed up |
|---|---|---|
| `/mnt/projects/cj-mills/` | Your own repos and active projects | Yes |
| `/mnt/projects/clients/`, `blender/`, `notes/` | Client work, Blender projects, notes | Yes |
| `/mnt/projects/records/` | Collected, can't be re-obtained, no single project owns it: `claude-transcripts/`, `site-analytics/`, `backups/` | Yes |
| `/mnt/projects/archive/` | Retired, kept for reference: `cjm-era/` and older repos | Yes |
| `/mnt/projects/upstream/` | Clones of other people's repos | No |
| `/mnt/projects/scratch/` | Disposable experiments | No |
| `/mnt/data/datasets/`, `models/`, `vm/` | Datasets, model weights, test VMs and ISOs | No |
| `/mnt/data/media/` | Read-mostly library; `images/` can't be re-obtained, so it is backed up | `images/` only |

The Qt tools from the cjm-substrate era keep working from `archive/cjm-era` through
compatibility links at their old paths, because their conda environment's editable
installs and scripts hard-code `/mnt/SN850X_8TB_EXT4/Projects/GitHub/cj-mills`. Editing
those would be rework on retired code; the links go when the era's tools do.

## Decisions

| Date | Decision |
|---|---|
| 2026-10-13 | Ansible (system) + chezmoi (user) + thin bootstrap; Nix/Home Manager rejected as primary because tutorials and devices target stock Ubuntu/JetPack/Pi OS and Windows is in scope. NixOS explored on the test partition. |
| 2026-10-13 | Single repo for all targets; Windows is a later phase using chezmoi + WinGet Configuration. |
| 2026-10-13 | 24.04 → 26.04 via **clean install** driven by this repo; in-place `do-release-upgrade` rejected (carries accumulated state, never exercises the fresh-install path). |
| 2026-10-13 | GNOME on Wayland as the 26.04 baseline (GNOME on 26.04 has no X11 session); KDE Plasma to be trialled on the test partition. |
| 2026-10-13 | Package source policy and containers-first rule as above. |
| 2026-10-13 | NVIDIA: open kernel modules (`nvidia-driver-<ver>-open`); no host CUDA toolkit by default; Docker + NVIDIA Container Toolkit. |
| 2026-10-13 | 1Password desktop app + `op` CLI installed; SSH agent; plaintext credential files migrated into 1Password. |
| 2026-10-13 | System cleanup: single swap (partition), Ansible-managed fstab by UUID, `-m 0` on ext4 data drives. |
| 2026-10-13 | Raw system snapshots are git-ignored; only curated inventory is committed. |
| 2026-10-13 | mise (from its apt repo) manages per-user runtimes and CLIs: Node LTS, uv, aws-cli, and npm-distributed CLIs via the `npm:` backend. NodeSource, `~/.npm-global` and Deno retired. mise shims go on PATH in `~/.profile` so GUI apps (e.g. MCP servers launched via `npx`) find them. |
| 2026-10-13 | Repository is **public** (`cj-mills/machine-setup`): bootstrap is a single `curl` with no auth step. Secrets never enter the repo; raw snapshots stay git-ignored. |
| 2026-10-13 | Vendor apt keys are fingerprint-pinned: a served key that doesn't match fails the run for manual review. Vendor packages that write their own apt source are handled per vendor: VS Code is told not to via debconf; Chrome and 1Password ignore any such setting and overwrite the same filename, so they are `self_managed` — the verified definition bootstraps the first install and the vendor's file is left alone afterwards (no rewrite/overwrite cycle, and key rotation arrives through signed package updates). Found by the 26.04 VM idempotence run. |
| 2026-10-13 | Release `.deb`s without an apt repo (Quarto) are pinned by version and SHA-256. |
| 2026-10-13 | Blender: official builds (not Flathub) under `/opt/blender`, one row per release in `blender_versions` with `blender-<series>` commands and a default `blender`; currently 5.2 LTS only, since projects target the latest LTS Python API. Releases are pinned by SHA-256 verified across three mirrors (`scripts/blender-pin.sh`); download.blender.org rejects scripted clients. API-heavy and agentic pipelines use the PyPI `bpy` wheel in a project-owned conda environment (isolated via cjm-substrate), version-matched to the installed Blender. |
| 2026-10-13 | Fresh-install testing uses a disposable QEMU/KVM VM (`scripts/test-vm.sh`, no root needed) with qcow2 snapshots: install once, snapshot, bootstrap, roll back. Inventory host `ms-test`. |
| 2026-10-22 | Local converges run `ansible-playbook` as root under one interactive `sudo` instead of Ansible's become password prompt. Ubuntu's default sudo since 25.10 is sudo-rs, whose prompt Ansible's sudo plugin doesn't recognise (Launchpad #2122414; the upstream fix is only on ansible-core `devel` after its 2.16–2.20 backports were reverted). Root is also the context of an unattended install. Rejected: switching the system `sudo` alternative back to sudo.ws on every machine. `primary_user` defaults to `SUDO_USER` with a guard against empty/root; collections install repo-locally (`ansible/collections/`). Revisit once a released ansible-core supports sudo-rs, for remote hosts that use become. |
| 2026-10-26 | Windows moves to its own drive (second 990 PRO) as a fresh install: it is now a development platform (Unity/Unreal, Windows AI stack), not just a test target, and 500 GB on the shared drive is too small. One OS per drive also gives each its own ESP, so neither OS's updates or reinstalls touch the other. Rejected: a Windows data drive alongside the shared C:, and growing C: into the old Storage partition. |
| 2026-10-26 | Linux drive uses LVM with deliberate under-allocation: ext4 grows online, shrinking needs a live USB, so free pool space serves both root growth and test-OS volumes. Rejected: plain partitions filling the drive, and unallocated space at the end of the drive. |
| 2026-10-26 | Single admin account on the fresh Windows install with Administrator protection (or UAC "Always notify"). Rejected: separate standard and admin accounts, whose friction on a single-user development machine splits per-user installs across profiles. |
| 2026-10-26 | Data drives are mounted at purpose-named paths by UUID via the `mounts` role. Old paths in use while converging are retired from fstab without unmounting and become compatibility symlinks after the next boot. |
| 2026-10-27 | Windows AI stack (Windows App SDK / Windows ML runtimes, Foundry Local) is installed per project, not in the base Windows setup: apps declare these runtimes as dependencies, and tutorials must document installing them, so a machine without them pre-installed matches what readers start from. A runtime moves into the base config once it's in daily use across projects. |
| 2026-10-27 | Windows layer: `windows/autounattend.xml` (local admin account, no stored password, no automatic device encryption, interactive disk choice), `windows/machine-setup/` (first-sign-in ESP check, `bootstrap.ps1`, WinGet Configuration schema 0.2). Windows Setup puts its boot files on any visible ESP, even on another drive, so other drives' ESPs are hidden during installation (`scripts/esp-visibility.sh`); repairing that after installation by resizing C: broke booting in the VM and was rejected. Verified end to end in the test VM from a clean install: all 62 units applied, a second test pass reports every unit in its desired state, and Windows boots with the other drive absent or its ESP visible. Runbook: `docs/windows-install.md`. |
| 2026-10-27 | Windows PowerShell's execution policy is RemoteSigned (machine scope, a configuration unit): a fresh Windows is "Restricted", which blocks every script, PowerShell profiles included. The first `bootstrap.ps1` run bypasses the policy for its own process only (`powershell -ExecutionPolicy Bypass -File`), the same way `autounattend.xml` starts `first-logon.ps1`. Rejected: setting the policy in `first-logon.ps1`, which would split one setting between a script and the configuration. Found on the real install: the test VM's `desktop-run` had launched every command under its own Bypass; it now runs commands under the machine's policy. |
| 2026-10-27 | Removed apps are kept removed by deleting the Windows Update orchestrator's "expedited apps" workflows for them (`UScheduler_Oobe`: CrossDeviceUpdate, DevHomeUpdate, OutlookUpdate, TFLUpdate = consumer Teams); EdgeUpdate, IA (Store business-critical updates) and LXP (language packs) stay. Deprovisioning alone didn't hold: in the VM, `usoclient CrossDeviceUpdate` reinstalled CrossDevice from the Store within 11 minutes of removal and again after a reboot (Store log `Acquisition;CrossDevice_UO-UsoClient`), and Dev Home likewise. With the workflows deleted, nothing came back over 2 hours including a reboot. Rejected: turning off Store automatic updates (`AutoDownload=2`), which would also stop updates to the apps that are kept. |
| 2026-10-27 | Chrome on Windows installs from Google's enterprise MSI, accepted only with a valid Google LLC Authenticode signature, instead of winget: Google replaces the file at its unversioned URL with every release, so winget's pinned checksum fails (`0x8A150011`) until the manifest catches up. That failed the real install's first bootstrap (Google published 156.0.8078.73 at 20:32 UTC; the manifest still had .48). Chrome updates itself afterwards, as on Linux (Google's apt repo). Of the other winget packages, only Steam's installer URL is unversioned, and that installer rarely changes; left on winget. |
| 2026-10-30 | The transcript archive and the site analytics pull are standalone user timers in `home/` (`claude-transcript-archive`, `site-analytics-pull`), on the workstation only, because the cjm-substrate project is being archived and both must outlive it. Their data is collected and can't be re-obtained, so it sits in `/mnt/projects/records/`, outside any project, for future projects to read: Claude Code prunes transcripts after about 30 days, and Cloudflare keeps about 26 weeks. The pull is standard library plus the `openssl` CLI so an unattended timer depends on no environment, and it keeps the old snapshot format, so history continues unbroken. Its credentials and the Cloudflare account ID and site tag are 1Password documents rendered by chezmoi, so none of them are in this public repository. Rejected: keeping them in `cjm-substrate`, and a conda or uv environment for one RSA signature. |
| 2026-10-30 | Interim backup: `backup-snapshot`, a weekly user timer writing dated `rsync --link-dest` snapshots to `/mnt/backup`, keeping the last 8. History is why it isn't a mirror, which would copy an accidental deletion over the only backup at the next run. Snapshots are plain folders, so restoring needs no tool, and unchanged files take no extra space. It covers what the content layout marks as backed up, about 545 GB on a 2 TB drive. The drive is in the same machine, so this doesn't cover theft, fire or a power surge, and it isn't encrypted; an off-site copy (NAS or cloud) remains a known gap. Rejected for now: restic or borg, which add a restore tool and a repository format for a stopgap. |

## Repository layout

```
bootstrap.sh                  fresh-machine entry point (curl | bash)
scripts/converge-system.sh    run the Ansible system layer for this host
scripts/snapshot-system.sh    read-only inventory of a running system
scripts/test-vm.sh            disposable UEFI test VMs (Linux and Windows) for the fresh-install path
scripts/prepare-windows-disk.sh, esp-visibility.sh   Windows drive preparation (docs/windows-install.md)
windows/                      Windows layer: answer file, first-sign-in scripts, WinGet Configuration
ansible/                      system layer: site.yml, inventory/, roles/
home/                         chezmoi source (.chezmoiroot), i.e. the user layer
  .chezmoiscripts/            hooks: re-converge on ansible/ change, `mise install` on mise config change
inventory/                    curated review of what each machine should have (raw/ is git-ignored)
docs/                         design and decisions
```

## Open questions

- Ownership of the `cjm-evidence-pull.timer` user unit (this repo vs cjm-substrate).
- VeraCrypt source (no 26.04 build confirmed yet).
- Whether to add game engines (Unity Hub, Godot, Unreal) as opt-in roles now or when a project needs them.
- Nemo: dropped for now; revisit after trying 26.04's Nautilus.
