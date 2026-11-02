---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# Windows reads the Linux data drive by wsl --mount, read-only

Windows reaches the Linux data drive by `wsl --mount` on demand, read-only, instead of keeping copies of datasets and model weights on `C:`. Tested on the real machine: `/mnt/data` mounted, and its images and videos opened from File Explorer through `\\wsl.localhost`. Only one OS runs at a time, so the drive is never shared live. Read-only because ext4 isn't Windows' own filesystem and nothing on the drive should change from there; work that writes uses `P:`. Disk numbers can change, and both 8 TB drives look alike, so check the contents after mounting.
