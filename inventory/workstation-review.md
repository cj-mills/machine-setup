# Workstation inventory review

Curated from the read-only snapshot of the current Ubuntu 24.04 install
(`scripts/snapshot-system.sh`, raw output in git-ignored `inventory/raw/`).
Each row proposes where the item lives in the new setup, following the package
source policy: distro apt → vendor apt repo → Flatpak (GUI) → per-user tool
managers → containers; Snap only where it is the best option.

**Decision column:** `keep` / `drop` / `?` — fill in during review.

## Desktop applications

| Item | Current source | Proposed source | Decision | Notes |
|---|---|---|---|---|
| Firefox | snap | Mozilla apt repo | keep | Ubuntu's default is the snap; Mozilla's repo gives a native .deb |
| Google Chrome | vendor apt | vendor apt | keep | |
| Brave | vendor apt | vendor apt | keep | |
| Thunderbird | snap | Flatpak | drop | |
| Signal | snap | Signal apt repo | keep | Official upstream repo (the Flatpak is community-maintained) |
| Zoom | snap | Flatpak | drop | |
| VLC | snap | Flatpak | keep | |
| VS Code | snap | Microsoft apt repo | keep | Snap confinement causes terminal/path quirks in dev work |
| Claude Desktop | vendor apt | vendor apt | keep | |
| Typora | vendor apt | vendor apt | keep | |
| Quarto | manual .deb | release .deb (version-pinned) | keep | No apt repo upstream |
| LibreOffice | apt (default) | apt | keep | |
| VeraCrypt | apt | vendor .deb or PPA | keep | |
| PIA VPN | manual installer (`/opt/piavpn`) | vendor installer | keep | Interactive installer; may stay a manual step |
| Nemo file manager | apt | apt (optional) | drop | Revisit after trying 26.04's Nautilus; if re-adopted, set it as the default file manager (`inode/directory` handler) |
| GParted, psensor, gnome-tweaks | apt | apt | keep | |
| Foliate, Flatseal, Bottles | Flatpak | Flatpak | keep | I installed Flatseal and Bottles to try and run Pokemon InfiniteFusion on Ubuntu, but encountered issues. I've been using Foliate. |
| Rhythmbox, Shotwell, Totem | apt (default) | apt (default) | keep | Have settings in dconf, so likely in use. User Note: I use shotwell a lot, but if there is a better alternative, we can discuss that. |
| Transmission | apt (default) | apt or Flatpak | keep | |
| Blender | unknown (config exists) | Official build, 5.2 LTS | keep | `blender_versions` in group_vars; `bpy` wheel lives in project conda envs |
| 1Password | browser extension only | 1Password apt repo: desktop app + `op` CLI | keep | Needed for SSH agent and secret templating |

## Developer tooling

| Item | Current source | Proposed source | Decision | Notes |
|---|---|---|---|---|
| git, git-lfs, build-essential, ninja, curl, ripgrep, pandoc, ffmpeg, imagemagick, sqlite3, xclip, poppler-utils, unzip, nvme-cli, lm-sensors, iotop, net-tools | apt | apt | keep | Core CLI set |
| gh | apt (Ubuntu, v2.45) | GitHub CLI apt repo | keep | Ubuntu's version lags well behind |
| cmake | snap + apt | apt, or Kitware apt repo for newer | keep | Currently installed twice |
| aws-cli | snap | mise | keep | |
| Node.js | NodeSource apt | mise (global LTS) | keep | Runtime for npm-distributed CLIs and `npx` MCP servers; projects pin versions in `mise.toml` |
| Deno | installer in `~/.deno` | — | drop | No known dependent (Quarto bundles its own); one line in mise config to restore |
| npm global CLIs | `~/.npm-global` (gemini-cli) | mise `npm:` backend | keep | Mechanism kept, `~/.npm-global` retired; Gemini CLI not reinstalled |
| Miniforge (conda/mamba) + ~27 named envs | installer in `~/miniforge3` | Miniforge installer (role) | keep | Envs are project-owned (cjm runtime envs) — recreate from projects, not machine setup |
| uv | present (`~/.local/share/uv`), binary not on PATH | mise | keep | |
| Claude Code | native installer (`~/.local/bin/claude`) | native installer | keep | |
| COLMAP build deps (boost, eigen, ceres, cgal, glog, gtest, qt5, mkl, …) | apt | **container** | drop from host | Matches COLMAP's source-build dep list; project stack, not host |
| Docker | purged (stale, unused) | Docker apt repo + NVIDIA Container Toolkit | keep | Central to the containers-first policy |
| VS Code extensions (14) | — | listed in chezmoi, installed by script | keep | Claude Code, Python/Pylance, C++/CMake, containers, Rainbow CSV |
| Personal scripts in `~/.local/bin` (fix_text, sluggify, timestamp, …) | hand-placed | chezmoi | keep | |

## NVIDIA

| Item | Current | Proposed | Notes |
|---|---|---|---|
| Driver | `nvidia-driver-595` (proprietary kernel module) | `nvidia-driver-<ver>-open` — **decided** | NVIDIA recommends the open kernel modules for Turing and newer (RTX 4090 qualifies) |
| CUDA toolkit | Ubuntu `nvidia-cuda-toolkit` 12.0 | none on host by default; NVIDIA CUDA repo only if host compilation is needed — **decided** | Conda/pip PyTorch and containers bring their own CUDA runtime; 12.0 is far behind the driver |
| Container runtime | none | Docker + NVIDIA Container Toolkit — **decided** | |

## Desktop settings (GNOME)

- **Extensions:** gTile (user-installed), plus Ubuntu's built-ins (dock, AppIndicators, desktop icons). Tiling Assistant has saved settings.
- **dconf:** ~500 lines, mostly app window state and notification entries. The deliberate settings worth managing are in
  `desktop/interface`, `peripherals/keyboard`, `mutter`, `shell`, `dash-to-dock`, `gtile`, `tiling-assistant`, `power`,
  `privacy`, `screensaver`, `nautilus/preferences`, `nemo/preferences`, `app-folders`, `world-clocks`. To curate key-by-key.
- **Session:** X11 today → Wayland on 26.04.
- **Default apps:** `~/.config/mimeapps.list` → chezmoi.

## User configuration (chezmoi candidates)

| Item | Notes |
|---|---|
| `~/.profile` | Already well-structured PATH setup — move as-is |
| `~/.bashrc` | Larger history + conda init block |
| `~/.gitconfig`, `~/.config/git/` | |
| `~/.config/gh/` | Config only; token comes from `gh auth login` or 1Password |
| `~/.config/user-dirs.dirs` + XDG symlinks | Documents/Downloads/Music/Pictures/Videos → `/mnt/Storage/` (shared NTFS) |
| `~/.config/monitors.xml` | Multi-monitor layout (X11 format; Wayland regenerates — re-check after switch) |
| `~/.nvidia-settings-rc` | |
| User systemd units (`cjm-evidence-pull.timer`) | cjm tooling — owned by cjm-substrate or here? **Open — user to answer.** |
| `~/.claude/`, `~/.cjm/`, `~/cjm-dev-graph-private/` | State, not config — back up, don't template |

## Secrets currently on disk → 1Password

Plaintext credential files present (names only): `~/.hf-write-token`, `~/.pypirc`, `~/.npmrc`, `~/.aws/`,
`~/cookies.txt`, `~/.ssh/`. In the new setup these are either rendered by chezmoi from 1Password at apply time,
or replaced by `op run` / the 1Password SSH agent so they never sit on disk.

## System

| Item | Current | Proposed |
|---|---|---|
| Swap | 64 GB partition **and** 8 GB `/swap.img` both active | Partition only (drop swapfile) — **decided** |
| fstab data mounts | Hand-edited; includes a stale NTFS entry for the reformatted 8TB drive | Managed by Ansible per-host vars, by UUID with `nofail` — **decided** |
| ext4 data drives | Default 5 % root reservation (~370 GB on the 8 TB drive) | `-m 0` on data-only filesystems — **decided** |
| Kernel | HWE kernel (`linux-generic-hwe-24.04`) | 26.04 GA kernel initially |
