# machine-setup — design

Declarative, re-runnable setup for every machine I work on: the primary Ubuntu
workstation, OS test installs, Jetson and Raspberry Pi deployment targets, and
(later) Windows. The same code handles a fresh install and ongoing maintenance:
it converges a machine to the described state rather than running one-shot steps.

## Targets

| Group | Machine(s) | OS | Arch | Managed how |
|---|---|---|---|---|
| `workstation` | Primary desktop (RTX 4090) | Ubuntu 26.04 LTS | x86_64 | Locally (Ansible `-c local` + chezmoi) |
| `testbed` | `nvme1n1p9` test partition (ESP: `nvme3n1p2`) | Rotating — NixOS first | x86_64 | Per-OS; chezmoi dotfiles carry over |
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

1. Back up `~` state (`~/.claude`, `~/.cjm`, shell history, anything not reproducible). Re-run `scripts/snapshot-system.sh` for a final inventory.
2. Boot the 26.04 installer with the autoinstall config; answer the storage step only (target `nvme1n1p6`, reuse ESP `nvme1n1p2`, keep swap `nvme1n1p8`, leave all other partitions untouched).
3. Unattended: OS install → first boot → bootstrap runs the Ansible system layer (no secrets needed).
4. Sign in to 1Password, then `chezmoi init --apply` for the user layer.

Validated in a 26.04 VM before running on hardware.

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
| 2026-10-13 | Vendor apt keys are fingerprint-pinned: a served key that doesn't match fails the run for manual review. Vendor packages that self-manage their apt sources (Chrome, VS Code) are configured not to, so Ansible is the single owner of every source definition. |
| 2026-10-13 | Release `.deb`s without an apt repo (Quarto) are pinned by version and SHA-256. |
| 2026-10-13 | Blender: official builds (not Flathub) under `/opt/blender`, one row per release in `blender_versions` with `blender-<series>` commands and a default `blender`; currently 5.2 LTS only, since projects target the latest LTS Python API. Releases are pinned by SHA-256 verified across three mirrors (`scripts/blender-pin.sh`); download.blender.org rejects scripted clients. API-heavy and agentic pipelines use the PyPI `bpy` wheel in a project-owned conda environment (isolated via cjm-substrate), version-matched to the installed Blender. |
| 2026-10-13 | Fresh-install testing uses a disposable QEMU/KVM VM (`scripts/test-vm.sh`, no root needed) with qcow2 snapshots: install once, snapshot, bootstrap, roll back. Inventory host `ms-test`. |
| 2026-10-22 | Local converges run `ansible-playbook` as root under one interactive `sudo` instead of Ansible's become password prompt. Ubuntu's default sudo since 25.10 is sudo-rs, whose prompt Ansible's sudo plugin doesn't recognise (Launchpad #2122414; the upstream fix is only on ansible-core `devel` after its 2.16–2.20 backports were reverted). Root is also the context of an unattended install. Rejected: switching the system `sudo` alternative back to sudo.ws on every machine. `primary_user` defaults to `SUDO_USER` with a guard against empty/root; collections install repo-locally (`ansible/collections/`). Revisit once a released ansible-core supports sudo-rs, for remote hosts that use become. |

## Repository layout

```
bootstrap.sh                  fresh-machine entry point (curl | bash)
scripts/converge-system.sh    run the Ansible system layer for this host
scripts/snapshot-system.sh    read-only inventory of a running system
scripts/test-vm.sh            disposable UEFI test VM for the fresh-install path
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
