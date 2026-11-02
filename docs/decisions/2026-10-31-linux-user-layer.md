---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# The Linux user layer lives in home/

The Linux user layer lives in `home/`: shell, git, personal scripts, VS Code and a curated list of GNOME settings, applied by script so app state stays out. Commits are signed with an SSH key held in 1Password, which can pause unattended agent commits until the app is unlocked; turning it off is one line. Credentials still needed (Hugging Face, PyPI, AWS) render from 1Password documents on the workstation only. Dock favorites stay manual. gTile is a pinned chezmoi external, our monitor extension links from its project on the data drive, and Smart Auto Move is dropped. Miniforge is a role pinned by checksum, conda environments stay with their projects. No Proton Drive on Linux yet: Proton has no sync client there; re-check later.
