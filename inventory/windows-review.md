# Windows inventory review

Curated from read-only snapshots of the current Windows 11 Pro 25H2 install
(`scripts/snapshot-windows.ps1`, raw output git-ignored), taken in both accounts: the
admin account (`INNOM-DT`, elevated) and the everyday account (`Personal`). The fresh
install goes on its own drive (see `docs/design.md`, drive layout), uses a single admin
account, and is described declaratively with WinGet Configuration.

**Source policy (Windows):** winget community source → Microsoft Store (via winget) for
Store-only apps → vendor installer as a last resort. Per-project dependencies (NuGet,
pip, conda) stay in projects, as on Linux.

**winget ID column:** IDs from the snapshot's `winget export` are confirmed; IDs marked
*(verify)* are expected IDs to check during the VM test of the configuration.

**Decision column:** `keep` / `drop` / `?`.

## Applications

| Item | winget ID | Decision | Notes |
|---|---|---|---|
| Brave | Brave.Brave *(verify)* | keep | Same browsers as Linux; Edge is built in |
| Google Chrome | Google.Chrome *(verify)* | keep |  |
| Firefox | Mozilla.Firefox *(verify)* | keep |  |
| 1Password + CLI | AgileBits.1Password, AgileBits.1Password.CLI *(verify)* | keep | SSH agent, secrets, as on Linux |
| Claude Desktop | *(verify)* | keep | As on Linux |
| Microsoft 365 (Office) | — | drop | Try ArtCraft's document/spreadsheet/slides apps first |
| ArtCraft | vendor installer | keep | Windows/macOS releases; Linux is build-from-source |
| Typora | appmakes.Typora | keep | Paid license |
| Blender | BlenderFoundation.Blender | keep | Pin 5.2 LTS, matching Linux |
| SumatraPDF | SumatraPDF.SumatraPDF | drop | Try ArtCraft's PDF app first |
| VLC | VideoLAN.VLC | keep |  |
| MakeMKV | GuinpinSoft.MakeMKV | drop | Reinstall if needed |
| mGBA | JeffreyPfau.mGBA | drop | Reinstall if wanted |
| Amazon Music | Amazon.Music | drop | `Personal` account; starts at login |
| TuneFab music converter | — | drop | Updater left in AppData; app itself not installed |
| Clipchamp | Store default | ? | |
| PowerToys | Microsoft.PowerToys | keep | In daily use |
| 7-Zip | 7zip.7zip | drop | Windows 11 handles common archive formats |
| WizTree | AntibodySoftware.WizTree | keep |  |
| balenaEtcher | — | drop | Updater left in AppData; app itself not installed |
| Samsung Magician | vendor installer | keep | SSD firmware/health (Windows-only) |
| Private Internet Access | PrivateInternetAccess.PrivateInternetAccess | keep | |
| Logitech software | — | drop | Installed for the mouse; not used |
| Futuremark SystemInfo | — | drop | Leftover from a benchmark |
| Steam | Valve.Steam | keep | One Windows library on the Windows drive (today: four libraries, one on a drive now ext4) |

## Drivers

| Item | Seen | Notes |
|---|---|---|
| NVIDIA driver 610.88 + PhysX | installed | NVIDIA App, on the Studio driver branch (stability for Blender/Unreal/CUDA); overlay off unless recording |
| AMD chipset software | installed | From AMD; Windows Update covers some |
| Realtek Ethernet | installed | Windows Update usually suffices |

## Development

| Item | winget ID | Decision | Notes |
|---|---|---|---|
| Visual Studio | *(verify; current Community edition)* | keep | Only remnants today. Workloads: Game development with C++ (Unreal), .NET desktop, Windows App SDK |
| Windows SDKs (17763, 22621, 26100) | — | — | Pulled in by Visual Studio workloads; nothing installed separately |
| IIS Express, Web Deploy, Azure Functions tools | Microsoft.WebDeploy | drop | Origin unknown; reinstall if a project needs it |
| Microsoft MPI | Microsoft.msmpi | drop | Origin unknown; reinstall if a project needs it |
| Chocolatey | — | drop | Superseded by winget |
| Git | Git.Git *(verify)* | keep | Not installed today |
| GitHub Desktop | GitHub.GitHubDesktop | keep | `Personal` account |
| VS Code | Microsoft.VisualStudioCode | keep | `Personal` account (user install) |
| CMake | Kitware.CMake *(verify)* | keep | Standalone, for project builds outside Visual Studio (like apt cmake on Linux) |
| Node.js / npm globals | via mise | keep | `Personal` has an npm global folder; mise runs on Windows too, matching Linux |
| Miniforge3 | CondaForge.Miniforge3 | keep | `Personal` account; conda for project environments, as on Linux |
| Mambaforge | — | drop | Old (2023) and superseded by Miniforge |
| uv | via mise | keep | As on Linux |
| WSL | Microsoft.WSL | keep | Feature enabled, no distros; distro choice later (e.g. Ubuntu, to test Linux-on-Windows tutorials) |
| Windows Terminal | Microsoft.WindowsTerminal | keep | Built in on Windows 11 |
| CUDA toolkit | Nvidia.CUDA *(verify)* | keep | Pinned version; Windows supports side-by-side versions per project need |
| Docker Desktop | Docker.DockerDesktop *(verify)* | keep | WSL2 backend with GPU; the reference setup for Windows users of your containers; no autostart |
| Unity Hub | Unity.UnityHub *(verify)* | keep | 8 GB Unity cache in `Personal`; editors per project |
| Epic Games Launcher + Unreal Engine | EpicGames.EpicGamesLauncher *(verify)* | keep | 13 GB Unreal cache in `Personal`; engine versions per project |
| Windows AI stack (Windows App SDK / Windows ML, Foundry Local) | — | per project | Installed when the first project needs it; see decision log |

## Windows features

| Feature | State | Decision |
|---|---|---|
| WSL, Virtual Machine Platform | enabled | keep |
| Windows Sandbox | off | keep (disposable VM for testing installers of your own products) |
| .NET Framework 3.5 (NetFx3) | enabled | drop unless a tool needs it |
| Work Folders client | enabled | drop |

## Settings and data

- Accounts: one admin account (Administrator protection, or UAC "Always notify"), replacing
  the admin + `Personal` pair.
- Page file: system-managed on the Windows drive (the old one was split onto the Storage partition).
- User folders: defaults on the Windows drive. Today `Personal`'s Documents, Downloads,
  Music, Pictures and Videos point at the shared Storage partition, which is going away;
  Linux-side data stays on the ext4 drives, reachable from Windows via `wsl --mount` when needed.
- Caches not worth keeping: pip (18 GB), Unreal (13 GB) and Unity (8 GB) caches in `Personal`.
