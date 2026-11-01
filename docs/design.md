# machine-setup — design

Declarative, re-runnable setup for every machine I work on: the primary Ubuntu
workstation, OS test installs, Jetson and Raspberry Pi deployment targets, and
(later) Windows. The same code handles a fresh install and ongoing maintenance:
it converges a machine to the described state rather than running one-shot steps.

## Targets

| Group | Machine(s) | OS | Arch | Managed how |
|---|---|---|---|---|
| `workstation` | Primary desktop (RTX 4090) | Ubuntu 26.04 LTS | x86_64 | Locally (Ansible `-c local` + chezmoi) |
| `testbed` | A disposable partition today; after the clean install, an LVM test-OS volume on the Linux drive (shared ESP) | Rotating — NixOS first | x86_64 | Per-OS; chezmoi dotfiles carry over |
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
2. Boot the 26.04 installer from media built by `scripts/build-install-media.sh`. Its storage section targets the Linux drive by serial and lays out the ESP and LVM pool from the drive-layout table; pressing Install on the page that shows this config is the only interactive step, and on a machine without that serial the installer stops before it.
3. Unattended: OS install → first boot → a service runs bootstrap as root, before the login screen, for the Ansible system layer including data-drive mounts (no secrets needed) → reboot into the finished system.
4. Enable the SSH agent and CLI integration in the 1Password app and sign in, then run `chezmoi apply` from a desktop terminal for the user layer.

Runbook: `docs/linux-install.md`. Rehearsed on the replica VM before running on hardware.

## Drive layout (workstation)

One OS per physical drive; data drives mounted by filesystem UUID at purpose-named
paths, so paths survive a drive replacement. Drives are addressed in commands by
`/dev/disk/by-id/…` (serial-based): kernel `nvmeN` names change between boots.

The workstation's drive inventory is kept with the owner's private workspace notes,
outside this repository.

Data-drive filesystems use no root reservation (`-m 0`) and GPT type "Linux
filesystem" (`scripts/prepare-data-disk.sh`). Mounts are managed by the `mounts` role
from `host_vars`.

## Content layout (workstation)

Content is sorted by how it behaves, which also decides what gets backed up.

The layout itself is kept with the owner's private workspace notes.

On Windows, `C:` keeps apps, game libraries and default user folders, and a Dev Drive at
`P:` holds work, using the same names as Linux: `P:\cj-mills`, `P:\upstream`, `P:\scratch`,
plus `P:\caches`. It is a growable VHDX on `C:`, so BitLocker covers it and `C:` is never
resized.

The Qt tools from the cjm-substrate era keep working from `archive/cjm-era` through
compatibility links at their old paths, because their conda environment's editable
installs and scripts hard-code `/mnt/SN850X_8TB_EXT4/Projects/GitHub/cj-mills`.
Editing those would be rework on retired code; the links
go when the era's tools do. `/mnt/SN850X_8TB_EXT4` is a plain folder holding only such
links (`mounts_links`).
`~/.cache/huggingface` is a chezmoi link to the model cache on `/mnt/data`.

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
| 2026-10-30 | Interim backup: `backup-snapshot`, a weekly user timer writing dated `rsync --link-dest` snapshots to `/mnt/backup`, keeping the last 8. History is why it isn't a mirror, which would copy an accidental deletion over the backup at the next run. Snapshots are plain folders, so restoring needs no tool, and unchanged files take no extra space. It covers what the content layout marks as backed up. Rejected for now: restic or borg, which add a restore tool and a repository format for a stopgap. |
| 2026-10-30 | Windows work lives on a Dev Drive at `P:`, set up by `configuration.winget`: a 2 TB growable VHDX on `C:`, ReFS, created with `diskpart` because `New-VHD` needs Hyper-V. Windows doesn't re-attach a VHDX at boot (tested), so a startup task does, as SYSTEM, before sign-in. `P:` mirrors `/mnt/projects`, and a high letter can't collide with other volumes. pip, uv, npm and NuGet caches move there too. The letter is assigned last: on the real machine, a lettered but unformatted volume made Explorer offer to format it, leaving NTFS instead of a Dev Drive, which the VM couldn't show because nobody clicks there. The unit verifies the result and repairs an empty volume. Verified in the VM from a clean install: all 66 units, and `P:` returns after reboots with its letter, trust and data. Rejected: a partition, because `C:` must never be resized. |
| 2026-10-31 | Windows reaches the Linux data drive by `wsl --mount` on demand, read-only, instead of keeping copies of datasets and model weights on `C:`. Tested on the real machine: `/mnt/data` mounted, and its images and videos opened from File Explorer through `\\wsl.localhost`. Only one OS runs at a time, so the drive is never shared live. Read-only because ext4 isn't Windows' own filesystem and nothing on the drive should change from there; work that writes uses `P:`. Disk numbers can change, and both 8 TB drives look alike, so check the contents after mounting. |
| 2026-10-31 | The Linux user layer lives in `home/`: shell, git, personal scripts, VS Code and a curated list of GNOME settings, applied by script so app state stays out. Commits are signed with an SSH key held in 1Password, which can pause unattended agent commits until the app is unlocked; turning it off is one line. Credentials still needed (Hugging Face, PyPI, AWS) render from 1Password documents on the workstation only. Dock favorites stay manual. gTile is a pinned chezmoi external, our monitor extension links from its project on the data drive, and Smart Auto Move is dropped. Miniforge is a role pinned by checksum, conda environments stay with their projects. No Proton Drive on Linux yet: Proton has no sync client there; re-check later. |

| 2026-10-31 | The Ubuntu install is a full autoinstall that stops at the desktop installer's Ready to install page, not an interactive storage section as first planned: the installer ignores `storage:` for an interactive section and offers its own screen, which can't express this layout (read from the 26.04.1 snap's subiquity and UI source). Without `autoinstall` on the kernel command line, that page shows the config itself and waits for Install, so the file opens by naming the drive it erases. The drive is matched by serial, so a machine without it stops with an error before that page; on the replica VM, a changed serial gave `matched no disk` and left all six disks byte-identical. |
| 2026-10-31 | Install media is the stock ISO repacked with `xorriso`, not a config copied onto a stick: a stick written from an ISO is read-only, and repacking means the test VM boots the same image as the real machine. The login password's hash is made at build time and stays out of the repository; the image holds a salted SHA-512 crypt hash with raised rounds, which a strong password makes safe to keep on a stick. Rejected: a NoCloud `CIDATA` volume, which needs a second volume and differs between the test and the real boot. |
| 2026-10-31 | First boot runs `bootstrap.sh` as root for a named user, before the login screen, instead of granting temporary passwordless sudo, which would leave a privilege window and possibly a stale file after a failure. It runs from a service rather than the installer's chroot because Docker, snaps and mounts need a running system. A failure stays on screen until answered (retry or skip) and the service runs again at each boot, so a walk-away install can't end at a login screen hiding a half-configured machine. |
| 2026-10-31 | The workstation follows the HWE kernel track (`linux-generic-hwe-26.04`, NVIDIA modules for that flavour), as today. The desktop image ships it, and autoinstall's `kernel` key can only add a kernel: with a GA pin the HWE metapackages stayed installed, so GRUB would have moved to a kernel without NVIDIA modules at the first HWE release. |
| 2026-10-31 | `scripts/test-vm.sh` gains a workstation replica (`VM_OS=replica`) so the install is tested unchanged: Secure Boot firmware, the Linux drive at its real size and serial with the old install's partitions, the other internal drives with their real serials and filesystem UUIDs, and media on a stick-sized USB disk. Access for tests comes from hooks on the media, as for Windows, so the config itself is identical. |
| 2026-10-31 | `/mnt/SN850X_8TB_EXT4` becomes a plain folder of links on the clean install, replacing the bind mount of the whole projects drive there. Only three paths under it are still hard-coded (`Projects/GitHub/cj-mills`, `claude-code-scratchpads`, `Model_Cache`), and everything else on the drive has moved to its new layout, so exposing the drive at the old path would only hide stale references. A symlink shows programs the resolved path, which the bind mount was chosen to avoid; that matters only for a session started inside `cjm-era`, and those are finished. |
| 2026-11-01 | ChatGPT desktop app from OpenAI's apt repo, as a fresh install: none of its sessions or settings are restored. OpenAI publishes its signing key only inside the package, so the repository keeps a copy pinned by fingerprint (`key_file`). The package leaves an existing source in place, so the role installs the package's own source at handover (`vendor_source`); otherwise our bootstrap key would stay in use and a rotated key would break updates. Rejected: installing the `.deb` from the `latest` URL, which has no pin to verify it against. |
| 2026-11-01 | Nsight Compute comes from Ubuntu's archive (`nsight-compute`, 2024.1 on 26.04), with its profiling option in the `nvidia` role, replacing a hand install in `/usr/local` and the older 2022.4 package beside it. Rejected: NVIDIA's CUDA apt repo (2026.3), a second source of NVIDIA packages next to a driver from Ubuntu's archive, for a tool used occasionally. |
| 2026-11-01 | Dropped from the `/etc` audit: the `bwrap` AppArmor profile (a failed experiment; `bwrap` runs on clean 26.04 without it), `fs.inotify.max_user_watches=524288` (the kernel scales this default with RAM, so on this machine the line should only lower it), and the NodeSource apt pins, which went with the repository. Covered already: the `lfs` filter in `/etc/gitconfig` comes from the `git-lfs` package, PIA writes its own routing tables, and there were no printers, polkit rules or sudoers changes. |
| 2026-11-01 | `backup-snapshot --again` takes a further snapshot on the same day, as `YYYY-MM-DD-HHMMSS`. One-a-day stays the default so a timer catching up after boot adds nothing, but that made a pre-wipe run on a timer day a silent no-op. |

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
inventory/                    curated review of what each machine should have (raw/ is git-ignored)
docs/                         design and decisions
```
