# machine-setup: notes for Claude

Declarative setup for the user's machines (public repo `cj-mills/machine-setup`).
Start with `README.md`; the decisions and their rationale live in `docs/design.md`
(decision log, drive layout, package policy); `docs/windows-install.md` is the Windows
install runbook; `inventory/*-review.md` hold the per-item keep/drop decisions.

## Layout

- `bootstrap.sh`, `scripts/converge-system.sh`: Linux entry points (Ansible system layer).
- `ansible/`: roles base, mounts, vendor_repos, release_debs, blender, docker, nvidia,
  flatpak, snaps. Hosts: `innom-dt` (workstation), `ms-test` (Linux test VM),
  `innom-lt` (laptop). Host data in `inventory/host_vars/`.
- `home/`: chezmoi source (`.chezmoiroot`); hooks re-converge on `ansible/` changes and
  run `mise install` on mise-config changes.
- `windows/`: `autounattend.xml` + `machine-setup/` (first-logon.ps1, ensure-own-esp.ps1,
  bootstrap.ps1, configuration.winget).
- `scripts/`: snapshot-system.sh / snapshot-windows.ps1 (read-only inventories),
  test-vm.sh, prepare-windows-disk.sh, esp-visibility.sh, blender-pin.sh.

## Working rules for this repo

- Public repo: never commit secrets or `inventory/raw/` (git-ignored; personal data).
- Commit locally as work progresses; push only when the user says so.
- Anything that erases or retypes disks: the user runs it (needs sudo). Address disks by
  `/dev/disk/by-id/...` only: kernel `nvmeN` names change between boots.
- Verify in a test VM before the user runs anything on real hardware.

## Testing

Linting (no system Ansible on the host): a scratch venv, `pip install ansible-lint`, then
in `ansible/`: `ansible-playbook site.yml --syntax-check` and
`ansible-lint --offline site.yml roles inventory` (passes the `production` profile).
Run Ansible commands with `</dev/null 2>&1 | cat` (it rejects non-blocking stdio).

Test VMs (`scripts/test-vm.sh`, QEMU/KVM, no root; state in
`~/.local/share/machine-setup/vm/<name>`):

- `VM_NAME=ms-test` (Ubuntu 26.04): snapshots `fresh-install`, `fresh-ssh` (SSH key +
  passwordless sudo). Cycle: `restore fresh-ssh`, `start`, `wait-ssh`, then bootstrap from
  local commits via the 9p share (`MACHINE_SETUP_REPO=file:///mnt/machine-setup`).
  `data-disk SIZE` adds a disk for mounts tests.
- `VM_NAME=ms-win` (Windows 11 Pro): snapshot `fresh-install` (post-install, pre-config).
  A decoy disk with a Linux-style ESP is attached first (`decoy.raw`; hide/show it with
  `scripts/esp-visibility.sh`; `VM_DECOY=0` boots without it). Installer image:
  `/mnt/data/win11-installer-usb.qcow2`. Copy changed files in with `scp` (key and
  known_hosts in the VM dir, port 2223, user `innom-dt`), then
  `scripts/test-vm.sh desktop-run '& C:\machine-setup\bootstrap.ps1 -AcceptAgreements'`.
  The user approved `--accept-configuration-agreements` for the test VM only.

## Lessons (each cost a debugging round)

- Bash reads scripts incrementally: editing a script while the user's terminal runs it
  (e.g. `test-vm.sh install`) once deleted a VM. Every script runs its logic inside
  `main()` with `main "$@"; exit` as the last line; keep that pattern.
- Don't `pkill -f` a pattern that also matches your own command line. Guard variable
  paths in `rm` with `${VAR:?}`.
- Ubuntu 25.10+ uses sudo-rs, whose prompt Ansible's become can't detect: local converges
  run `ansible-playbook` under one interactive `sudo` instead (no `--ask-become-pass`).
- Chrome and 1Password write their own apt source on install: `self_managed` repos
  bootstrap the first install, then hand over.
- download.blender.org returns 403 to scripts: Blender comes from official mirrors,
  pinned by SHA-256 cross-checked across three (`scripts/blender-pin.sh` prints Linux
  and Windows pins).
- Windows Setup uses any visible ESP, even on another drive; with two ESPs on the target
  it fails (0x80073B92). Hide other ESPs during install; never resize C: afterwards.
- Windows 11 auto-enables device encryption even for local accounts: prevented in the
  answer file; BitLocker is enabled deliberately with the key in 1Password.
- WinGet configuration runner: SSH key logons can't do Store/Appx installs (use
  `desktop-run`); it hosts PowerShell 7, so Appx/DISM cmdlets need `powershell.exe` and
  WindowsOptionalFeature needs `dism.exe`; Script tests read the registry with
  `[Microsoft.Win32.Registry]::GetValue` (Get-ItemPropertyValue throws on missing values);
  `winget configure --enable` updates winget mid-run (wait); the first unit using a
  newly installed module can fail (bootstrap runs a test pass first).

## Status (2026-10-27)

Done and verified: Linux system layer (VM, clean install + idempotent re-runs); data-drive
mounts on the workstation (`/mnt/projects` with the old path as a bind mount, `/mnt/data`);
Windows layer end to end in the VM (62/62 units, second test pass all in desired state).

Next:
1. Real Windows install, following `docs/windows-install.md` (user runs it).
2. Linux dotfiles into `home/`: `.bashrc` (history, conda init), git with 1Password SSH
   signing, `~/.local/bin` scripts (read each before committing: public repo), VS Code
   extensions, curated GNOME settings incl. event sounds off, Miniforge, Proton Drive
   Linux client if one exists.
3. Ubuntu 26.04 autoinstall config (LVM: 2 GB ESP, root ~2.5 TB, 64 GB swap, ~1 TB free),
   then the Ubuntu clean install (back up `~/.claude`, `~/.cjm` and other state first).

Later: Visual Studio + workloads (when a C++/Unreal project needs it; confirm
`Microsoft.VisualStudio.DSC/VSComponents` IDs in the VM), Dev Drive (growable VHDX,
re-attached at boot), Blender 5.2.3 bump (both platforms), convert the 860 EVO (`games`)
and BX500s (`backup`, `archive`), Jetson and Pi roles. Open: whether the
`cjm-evidence-pull.timer` user unit belongs here or in cjm-substrate.
