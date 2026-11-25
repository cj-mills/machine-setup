---
status: accepted
decided_by: user (Rust belongs in machine-setup); form chosen in session
source: 2026-11-08-rust-wasm-toolchain-via-mise
---
<!-- Generated from the vault note 2026-11-08-rust-comes-from-mise-and-yields-to-rust-toolchain-toml; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

Rust and WebAssembly tools come from mise.

On Linux, the global mise config (`home/dot_config/mise/config.toml`) adds the Rust and WebAssembly tools to the per-user runtimes of `2026-10-13-mise-user-runtimes`:

- `rust` (mise's core backend, which drives rustup): the `stable` toolchain with rustup's `default` profile (adds clippy and rustfmt) and the `wasm32-unknown-unknown` target. rustup and the toolchains live in `~/.rustup` and `~/.cargo`, mise's defaults.
- `idiomatic_version_file_enable_tools = ["rust"]`, so mise reads a project's `rust-toolchain.toml`.

Projects pin their own versions: the Rust toolchain and its targets in `rust-toolchain.toml`. The global entries are only defaults for directories that pin nothing. The WebAssembly tools: `2026-11-08-wasm-bindgen-and-wasm-opt-come-from-mise-pinned-per-project`. Windows is out of scope here.

## Why
- mise sets `RUSTUP_TOOLCHAIN` for the toolchain it selects, and rustup ranks that above `rust-toolchain.toml`, so without the setting the global `stable` would override every project's pin (doc: mise.jdx.dev/lang/rust). With it, mise selects the project's channel and installs its targets and components.
- The system side needs only a C linker and libc headers for native builds, which the `base` role already installs (`build-essential` in `group_vars/all.yml`). The WebAssembly target links with rust-lld, which ships in the toolchain.

## Rejected
- Ubuntu's `rustc`/`cargo` and `binaryen` packages: one version per release, not the per-project pins Rust projects expect, and they lag upstream.
- rustup from `sh.rustup.rs` directly (outside mise): a second runtime manager with its own PATH edits; mise already owns this layer and adds no PATH edits of its own (its shims are on PATH in `~/.profile`).
