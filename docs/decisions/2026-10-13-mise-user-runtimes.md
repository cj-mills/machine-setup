---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-10-13-mise-user-runtimes; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# mise manages per-user runtimes and CLIs

mise (from its apt repo) manages per-user runtimes and CLIs: Node LTS, uv, aws-cli, and npm-distributed CLIs via the `npm:` backend. NodeSource, `~/.npm-global` and Deno retired. mise shims go on PATH in `~/.profile` so GUI apps (e.g. MCP servers launched via `npx`) find them.
