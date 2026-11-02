---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# Transcript archive and site analytics pull are standalone user timers

The transcript archive and the site analytics pull are standalone user timers in `home/` (`claude-transcript-archive`, `site-analytics-pull`), on the workstation only, because the cjm-substrate project is being archived and both must outlive it. Their data is collected and can't be re-obtained, so it sits in `/mnt/projects/records/`, outside any project, for future projects to read: Claude Code prunes transcripts after about 30 days, and Cloudflare keeps about 26 weeks. The pull is standard library plus the `openssl` CLI so an unattended timer depends on no environment, and it keeps the old snapshot format, so history continues unbroken. Its credentials and the Cloudflare account ID and site tag are 1Password documents rendered by chezmoi, so none of them are in this public repository. Rejected: keeping them in `cjm-substrate`, and a conda or uv environment for one RSA signature.
