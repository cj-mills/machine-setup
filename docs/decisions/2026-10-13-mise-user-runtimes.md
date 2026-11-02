---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# mise manages per-user runtimes and CLIs

mise (from its apt repo) manages per-user runtimes and CLIs: Node LTS, uv, aws-cli, and npm-distributed CLIs via the `npm:` backend. NodeSource, `~/.npm-global` and Deno retired. mise shims go on PATH in `~/.profile` so GUI apps (e.g. MCP servers launched via `npx`) find them.
