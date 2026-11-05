---
status: accepted
decided_by: agent, approved by user
source: session 2026-11-04-source-ingestion-pipelines-tool-survey (hub)
---
# Claude Code's global instructions live with the owner's private notes; chezmoi links them

**Decision.** `~/.claude/CLAUDE.md`, the instructions Claude Code loads in every session, is
a chezmoi symlink (`home/private_dot_claude/symlink_CLAUDE.md`) to a file in the owner's
private notes. This repository holds only the link. The content is versioned with the
private notes, where the rulings it records are made.

**Why.** The file holds the owner's working rules for agents: account and plan details,
and dated rulings on how sessions should work. That belongs in the private tier, not in a
public repository. Before this, it was an untracked file, so its edits had no history and
it wasn't backed up, since `~` isn't. The same split already serves `backup-snapshot`,
whose public script reads a configuration folder that chezmoi links to the private notes
(`2026-11-02-backup-policy-in-config.md`).

**Rejected.**
- **The content in this repository:** it is public.
- **Leaving it untracked:** no history and no backup.

**Limits.** If the private notes' drive isn't mounted, the link dangles and sessions start
without global instructions. That is the same exposure the backup configuration accepts.
On Windows, the link waits until the private notes are cloned there.
