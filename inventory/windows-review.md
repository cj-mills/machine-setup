# Windows inventory review

Curated from the read-only snapshot of the current Windows 11 Pro 25H2 install
(`scripts/snapshot-windows.ps1`, raw output git-ignored). The fresh install goes on its
own drive (see `docs/design.md`, drive layout) and is described declaratively with
WinGet Configuration.

Snapshot coverage: the admin account (`INNOM-DT`, elevated). The everyday account
(`Personal`) still needs its own run for per-user apps (e.g. Amazon Music, PowerToys).

**Source policy (Windows):** winget community source → Microsoft Store (via winget) for
Store-only apps → vendor installer as a last resort. Per-project dependencies (NuGet,
pip, conda) stay in projects, as on Linux.

**Decision column:** `keep` / `drop` / `?`.

## Applications

| Item | Seen in snapshot | Decision | Notes |
|---|---|---|---|
| Brave, Google Chrome, Firefox | installed | ? | Edge is built in |
| 1Password + CLI | not installed | keep | SSH agent, secrets, as on Linux |
| Claude Desktop | not installed | ? | |
| Microsoft 365 (Office) | installed (Click-to-Run) | ? | |
| Typora | installed | ? | |
| Blender | 5.0.0 | keep | Pin 5.2 LTS, matching Linux |
| ArtCraft | not installed | ? | Windows/macOS releases; Linux is build-from-source |
| VLC | installed | ? | |
| MakeMKV | installed | ? | |
| mGBA | installed | ? | |
| Amazon Music | `Personal` account | ? | |
| TuneFab music converter | updater in AppData | ? | |
| Clipchamp | Store default | ? | |
| PowerToys | `Personal` account | ? | |
| 7-Zip | installed | ? | |
| WizTree | installed | ? | |
| Samsung Magician | installed | keep | SSD firmware/health (Windows-only) |
| Private Internet Access | installed | keep | |
| Logitech software | Logi Download Assistant | ? | Which device needs it? |
| Futuremark SystemInfo | installed | drop | Leftover from a benchmark |
| Steam | installed; libraries on C:, the 860 EVO, both BX500s | keep | Windows library moves to the Windows drive |

## Drivers

| Item | Seen | Notes |
|---|---|---|
| NVIDIA driver 610.88 + PhysX | installed | Driver-only install vs NVIDIA App: decide |
| AMD chipset software | installed | From AMD; Windows Update covers some |
| Realtek Ethernet | installed | Windows Update usually suffices |

## Development

| Item | Seen | Decision | Notes |
|---|---|---|---|
| Visual Studio | partial remnants (installer, SDKs, .NET 9 SDK) | keep | Workloads: Game development with C++ (Unreal), .NET desktop, Windows App SDK |
| Windows SDKs (17763, 22621, 26100) | installed | — | Installed by Visual Studio workloads; keep only what workloads pull in |
| IIS Express, Web Deploy, Azure Functions tools | installed | ? | From Visual Studio web/Azure workloads |
| Microsoft MPI | installed | ? | Usually pulled in by an ML/HPC tool |
| Chocolatey | installed | drop | Superseded by winget |
| Git | not installed | keep | |
| VS Code | not installed | keep | |
| WSL | feature enabled, no distros | keep | Distro choice later (e.g. Ubuntu, to test Linux-on-Windows tutorials) |
| Python | Store alias only | keep | Miniforge (conda) and uv, as on Linux |
| CUDA toolkit | not installed | ? | Only if building CUDA code natively on Windows |
| Docker Desktop | not installed | ? | WSL2 backend; licensing terms apply to companies above a size threshold |
| Unity Hub | updater in AppData | keep | Editors per project |
| Epic Games Launcher + Unreal Engine | not installed | keep | Engine versions per project |
| Windows AI stack (Windows App SDK / Windows ML, Foundry Local) | not installed | ? | Per-project SDKs; machine-level runtime only if needed |

## Windows features

| Feature | State | Decision |
|---|---|---|
| WSL, Virtual Machine Platform | enabled | keep |
| Windows Sandbox | off | ? (disposable VM for testing installers of your own products) |
| .NET Framework 3.5 (NetFx3) | enabled | drop unless a tool needs it |
| Work Folders client | enabled | drop |

## Settings and data

- Page file: system-managed on the Windows drive (the old one was split onto the Storage partition).
- User folders: defaults on the Windows drive. Linux-side data stays on the ext4 drives;
  reachable from Windows via `wsl --mount` when needed.
- Steam: Windows keeps its own library on the Windows drive; Linux gets the 860 EVO.
