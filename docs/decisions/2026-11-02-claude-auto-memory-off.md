---
status: accepted
decided_by: user
source: session 2026-11-02-hub-setup
---
# Claude Code's auto memory is off

**Decision.** `~/.claude/settings.json` sets `"autoMemoryEnabled": false`, managed by a
chezmoi modify template that sets only that key, because Claude Code writes the rest of
the file itself.

**Why.** Auto memory keeps what sessions learn in `~/.claude/projects/<path>/memory/`,
where people and other agents don't see it and it splits knowledge between itself and
the project's own records. The owner keeps that knowledge in plain files other agents
can read too.

**Rejected.** The `CLAUDE_CODE_DISABLE_AUTO_MEMORY` environment variable, which only
works where the session inherits it; the setting is read by every Claude Code entry point.
