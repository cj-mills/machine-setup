# machine-setup

Declarative setup for my machines: an Ubuntu workstation, Jetson and Raspberry Pi
deployment targets, OS test installs and, later, Windows. Ansible handles the
system layer, chezmoi handles the user layer, and 1Password holds every secret,
so nothing sensitive lives in this repository. The same code sets up a fresh
install and keeps an existing machine converged.

Design and decisions: [docs/design.md](docs/design.md).

## Fresh machine

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/cj-mills/machine-setup/main/bootstrap.sh)"
```

This installs Ansible and chezmoi, clones the repo and converges the system layer.
Then sign in to 1Password (enable CLI integration and the SSH agent under
Settings → Developer) and run:

```bash
~/.local/bin/chezmoi apply
```

(`~/.local/bin` joins `PATH` at your next login; after that, plain `chezmoi` works.)

## Day to day

```bash
chezmoi update
```

This pulls the repo and applies dotfiles. It re-runs Ansible only when something
under `ansible/` changed, and runs `mise install` only when the mise config changed.
To converge the system layer directly, or preview changes:

```bash
scripts/converge-system.sh --check --diff
```

## Adding a machine

Add the host (its short hostname) to `ansible/inventory/hosts.yml`, with any
host-specific values in `ansible/inventory/host_vars/<host>.yml`.

## Windows

Windows is described by `windows/` (answer file, first-sign-in scripts and a WinGet
Configuration). Install procedure: [docs/windows-install.md](docs/windows-install.md).
After installation, from Terminal (Admin):
`powershell -NoProfile -ExecutionPolicy Bypass -File C:\machine-setup\bootstrap.ps1`.
