# machine-setup: notes for Claude

Declarative setup for the user's machines (public repo `cj-mills/machine-setup`).
Start with `README.md`; the decisions and their rationale live in `docs/design.md`
(decision log, drive layout, package policy); `docs/windows-install.md` is the Windows
install runbook; `inventory/*-review.md` hold the per-item keep/drop decisions.

## Layout

- `bootstrap.sh`, `scripts/converge-system.sh`: Linux entry points (Ansible system layer).
- `ansible/`: roles base, mounts, vendor_repos, release_debs, blender, docker, nvidia,
  flatpak, snaps, test_vms. Hosts: `innom-dt` (workstation), `ms-test` (Linux test VM),
  `innom-lt` (laptop). Host data in `inventory/host_vars/`.
- `home/`: chezmoi source (`.chezmoiroot`); hooks re-converge on `ansible/` changes and
  run `mise install` on mise-config changes. Workstation-only user timers
  (`claude-transcript-archive`, `site-analytics-pull`, `backup-snapshot`) are gated in
  `.chezmoiignore`.
- `windows/`: `autounattend.xml` + `machine-setup/` (first-logon.ps1, ensure-own-esp.ps1,
  bootstrap.ps1, configuration.winget).
- `scripts/`: snapshot-system.sh / snapshot-windows.ps1 (read-only inventories),
  test-vm.sh, prepare-windows-disk.sh, prepare-data-disk.sh, esp-visibility.sh,
  blender-pin.sh.

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
`/mnt/data/vm/<name>` on the workstation, else `~/.local/share/machine-setup/vm/<name>`):

- `VM_NAME=ms-test` (Ubuntu 26.04): snapshots `fresh-install`, `fresh-ssh` (SSH key +
  passwordless sudo). Cycle: `restore fresh-ssh`, `start`, `wait-ssh`, then bootstrap from
  local commits via the 9p share (`MACHINE_SETUP_REPO=file:///mnt/machine-setup`).
  `data-disk SIZE` adds a disk for mounts tests.
- `VM_NAME=ms-win` (Windows 11 Pro): snapshot `fresh-install` (post-install, pre-config).
  A decoy disk with a Linux-style ESP is attached first (`decoy.raw`; hide/show it with
  `scripts/esp-visibility.sh`; `VM_DECOY=0` boots without it). Installer image:
  `/mnt/data/vm/isos/win11-installer-usb.qcow2`. Copy changed files in with `scp` (key and
  known_hosts in the VM dir, port 2223, user `innom-dt`), then
  `scripts/test-vm.sh desktop-run 'powershell -NoProfile -ExecutionPolicy Bypass -File C:\machine-setup\bootstrap.ps1 -AcceptAgreements'`
  (the runbook's command; desktop-run runs it as if typed at a fresh prompt).
  The user approved `--accept-configuration-agreements` for the test VM only.
  The current `fresh-install` snapshot predates VM autologon: for `desktop-run` after a
  reboot, set Winlogon `AutoAdminLogon=1`, `DefaultUserName`, `DefaultPassword=''` over SSH.
  Windows' console output can vanish through `grep`: write to a file and `scp` it back.

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
  newly installed module can fail (bootstrap runs a test pass first);
  PSDscResources/Registry can't remove a key (`Ensure: Absent` resolves it as a file
  path): use a Script unit with the .NET registry API.
- Removed apps coming back: Windows Update's orchestrator runs "expedited apps"
  workflows (`HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe`,
  run times in `..\USOShared\ScheduleTimeDump`) that install their app from the Store
  whenever it's missing; Deprovisioned keys don't stop them. Trace a reinstall with the
  Store/Operational log's `ClientAppId = Acquisition;<Name>_UO-UsoClient-...`. In the
  VM, event times jump 7 h once `rtc-utc` takes effect at the next boot.
- winget fails a package whose vendor URL is unversioned (e.g. Chrome's enterprise MSI)
  with `0x8A150011` (checksum mismatch) after each vendor release until winget-pkgs
  catches up: install those from the vendor and verify the Authenticode signer instead.
- In a narrow terminal, `lsblk` (util-linux 2.39) never finishes and floods output:
  scripts pipe it through `cat`. Tests with piped output can't catch terminal-only bugs.
- Two sessions can't share a test VM. For a second one, copy a snapshot:
  `qemu-img convert -U -O qcow2 -l snapshot.name=fresh-ssh`, plus `OVMF_VARS`, the SSH key
  and a new `VM_NAME` with `VM_SSH_PORT`.
- A partition with a drive letter but no filesystem makes Explorer offer to format it,
  which interfered with a Dev Drive format on the real machine (nobody clicks in the VM):
  format first, assign the letter last. ReFS is only available on Pro through `-DevDrive`.
- winget unit descriptions are YAML flow values: a `:` breaks parsing and a `,` truncates
  them. A VHDX isn't re-attached at boot; `New-VHD` needs Hyper-V (use `diskpart`).
- `.chezmoiignore` gates on `.chezmoi.hostname`, and an ignored template is never
  rendered, so `onepasswordDocument` only runs on the workstation (not in `ms-test`).
- Ubuntu's AppArmor profile for swtpm only allows the home directory and a few system
  paths, so Windows VMs outside it fail silently at `swtpm` (see `journalctl -k`): the
  `test_vms` role adds the VM directory to `local/usr.bin.swtpm`.
- A fresh Windows runs no PowerShell scripts (policy "Restricted"); the test harness's
  own `-ExecutionPolicy Bypass` was inherited by its payloads and hid this until the
  real install. Test the exact command the runbook gives, with nothing the harness adds.

## Status (2026-10-31)

The Ubuntu clean install on the Linux 990 PRO (…123428Y) is the goal. Everything below
"Next" comes before the wipe unless it says otherwise. Keep this session's folder path
(`/mnt/SN850X_8TB_EXT4/Projects/Utility_Projects/machine-setup`) until the final move:
Claude Code keys history and memory by path.

Done and verified:
- Linux system layer: VM, clean install and idempotent re-runs.
- Linux user layer in `home/`: on clean 26.04, full `bootstrap.sh` plus `chezmoi apply`
  passed 33 checks, and a second run changes nothing. Decisions are in `docs/design.md`.
- Windows on the second 990 PRO: all units applied, BitLocker on (key in 1Password), Dev
  Drive live and trusted at `P:`, 66 units in the VM. `wsl --mount` worked read-only on
  `/mnt/data` (disk numbers change; check the contents), so Windows mounts, not copies.
  Known and accepted: Explorer opens `P:` at restart. Windows treats the VHDX as removable
  (Explorer shows Eject), so AutoPlay's "Removable drive" choice is the likely cause; not
  reproduced in the VM. User leftovers: Start pins, VLC audio default.
- Data drives match `docs/design.md`, "Content layout". Originals of everything moved are
  deleted, with checksums first. `Projects/Utility_Projects` and `Utility_CLI_Scripts`
  (redundant now, can be archived) remain at their old paths.
- `/mnt/backup` (BX500 #2): the weekly `backup-snapshot` timer is on, and the first
  snapshot (543 GB) matched by checksum. Not encrypted and in the same machine; off-site
  backup (NAS or cloud) is a known gap. BX500 #1 matches `/mnt/archive` (129 GB
  `archive/invigo`), not yet in `mounts_list`.
- cjm-substrate retired: 41 repos private and archived, PyPI releases stay. Still public:
  `cjm-demucs-v4`, `cjm-design-system`, tutorial packages, the 59 cjm repos outside that
  folder. `medium` and `medium-record` are deleted; `nalvo` and `cjm-archive` are kept.
- Standalone timers run here: `claude-transcript-archive`, `site-analytics-pull`,
  `backup-snapshot`. The old `cjm-*` timers are disabled. Data is in `/mnt/projects/records`.
- 1Password holds `site-analytics-*`, `hf-write-token`, `pypirc`, `aws-credentials` and
  `aws-config` documents, verified against the working files, plus the `git-signing` SSH
  key, whose public half is on GitHub and in `home/dot_gitconfig.tmpl`. `op` and `chezmoi`
  are in `~/.local/bin` here. Never run a bare `chezmoi apply` on this install: it would
  replace `.bashrc`/`.profile` and converge the system; use targeted paths with
  `--source="$PWD"`.
- cjm-era Qt tools on clean 26.04 (Wayland and X11, real graph): with the links below, a
  fresh Miniforge and only env `cjm-transcript-correction-core` restored. Their capability
  Python is `cjm-transcript-correction-core/runtime/envs/`, inside the archive; `.cjm/`
  must come along. The scratchpad resolves the link, so its live transcript feed looks
  under `-mnt-projects-archive-cjm-era-*`; that only matters for a session running there.

Monitor Reconnect Restore is ported to GNOME 46 and 50 in its own repo: commits `1dd7f08`
and `be7e51c`, local, not pushed there. Its test scenarios passed on both versions, but a
real monitor reconnect on 26.04 is untested, and this desktop runs the old code until the
next login. `home/` links it from `/mnt/projects/cj-mills/monitor-reconnect-restore` after
the final move.

Next:
1. Ubuntu 26.04 autoinstall config: not written yet. LVM on the Linux drive by serial
   (2 GB ESP, root ~2.5 TB, 64 GB swap, ~1 TB free), hostname `innom-dt`, user `innom-dt`;
   confirming the target is the only interactive step (`docs/design.md`, "Workstation
   install flow"). Test a real install in a VM first.
2. Code still needed for the install:
   - `mounts` role: replace the `mounts_aliases` bind mount with a plain
     `/mnt/SN850X_8TB_EXT4` folder of links: `Projects/GitHub/cj-mills` ->
     `/mnt/projects/archive/cjm-era`, `claude-code-scratchpads` -> the same under
     `archive/cjm-era`, `Model_Cache` -> `/mnt/data/models`.
   - chezmoi: `~/.cache/huggingface` -> `/mnt/data/models/huggingface`, and links back for
     `~/.cjm` and `~/cjm-dev-graph-private` (their tools hard-code those paths).
   - Add BX500 #1 to `mounts_list` as `/mnt/archive` (ext4, UUID
     `4fe5c6cb-514a-45e6-9fad-c0547df15b9a`).
3. Final steps, in one sitting, right before the wipe:
   - Move `Projects/Utility_Projects/*`, including this repo, into `/mnt/projects/cj-mills/`,
     rename their `~/.claude/projects/` folders (`christianjmills` too), re-run
     Monitor Reconnect Restore's `install.sh`, and fix `SOURCES` in `backup-snapshot`.
     `protonmail-archive`'s conda env points at its current path.
   - Copy `~/.claude`, `~/.claude.json`, `~/.bash_history` and `~/.local/share/backgrounds`
     somewhere that's backed up. Move `~/cjm-dev-graph-private` (4 uncommitted changes) and
     `~/.cjm` into `archive/cjm-era`.
   - Re-sync `/mnt/Storage` to `archive/storage-partition`: `~/Downloads` still points there.
     Excluded so far: Windows system items only.
   - Decide about `~/cookies.txt` (plaintext; `inventory/workstation-review.md` lists it),
     then re-run `scripts/snapshot-system.sh`, and take a final `backup-snapshot`.
4. Clean install. Then: enable the SSH agent and CLI integration in the 1Password app, sign
   in, `chezmoi apply` from a desktop terminal (GNOME settings need a session bus), test
   commit signing and gTile in a real session, restore env
   `cjm-transcript-correction-core` from `/mnt/data/transfer/miniforge3/envs/`, restore home
   folders from `archive/storage-partition`, re-check Proton Drive for Linux (no official
   sync client as of 2026-10; re-check), and pin the dock by hand.

Later: Visual Studio + workloads (when a C++/Unreal project needs it; confirm
`Microsoft.VisualStudio.DSC/VSComponents` IDs in the VM), Blender 5.2.3 bump (both
platforms), convert the 860 EVO (`games`), Jetson and Pi roles, off-site backup.
