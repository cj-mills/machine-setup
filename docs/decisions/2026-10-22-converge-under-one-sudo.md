---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# Local converges run under one interactive sudo

Local converges run `ansible-playbook` as root under one interactive `sudo` instead of Ansible's become password prompt. Ubuntu's default sudo since 25.10 is sudo-rs, whose prompt Ansible's sudo plugin doesn't recognise (Launchpad #2122414; the upstream fix is only on ansible-core `devel` after its 2.16–2.20 backports were reverted). Root is also the context of an unattended install. Rejected: switching the system `sudo` alternative back to sudo.ws on every machine. `primary_user` defaults to `SUDO_USER` with a guard against empty/root; collections install repo-locally (`ansible/collections/`). Revisit once a released ansible-core supports sudo-rs, for remote hosts that use become.
