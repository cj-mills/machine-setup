---
status: accepted
decided_by: user (Rust belongs in machine-setup); form chosen in session
source: session 2026-11-08-machine-setup-rust-toolchain
---
# Rust and WebAssembly tools come from mise

**Decision.** On Linux, the global mise config (`home/dot_config/mise/config.toml`) adds
the Rust and WebAssembly tools to the per-user runtimes of
`2026-10-13-mise-user-runtimes`:

- `rust` (mise's core backend, which drives rustup): the `stable` toolchain with
  rustup's `default` profile (adds clippy and rustfmt) and the `wasm32-unknown-unknown`
  target. rustup and the toolchains live in `~/.rustup` and `~/.cargo`, mise's defaults.
- `wasm-bindgen` (with `wasm-bindgen-test-runner`) from its GitHub releases
  (`github:wasm-bindgen/wasm-bindgen`): static musl binaries, which mise checks against
  GitHub's asset digest and the release's artifact attestations. The aqua registry has
  no entry for it.
- `wasm-opt` from binaryen through the aqua registry (`aqua:WebAssembly/binaryen`),
  checked against GitHub's asset digest. The release is the whole toolkit (about 110 MB
  compressed); the other `wasm-*` tools come with it.
- `idiomatic_version_file_enable_tools = ["rust"]`, so mise reads a project's
  `rust-toolchain.toml`.

Projects pin their own versions: the Rust toolchain and its targets in
`rust-toolchain.toml`; `wasm-bindgen` and binaryen in the project's `mise.toml`. The
global entries are only defaults for directories that pin nothing.

**Why.**
- mise sets `RUSTUP_TOOLCHAIN` for the toolchain it selects, and rustup ranks that above
  `rust-toolchain.toml`, so without the setting the global `stable` would override every
  project's pin (doc: mise.jdx.dev/lang/rust). With it, mise selects the project's
  channel and installs its targets and components.
- The `wasm-bindgen` CLI must be the same version as the `wasm-bindgen` crate in the
  project's `Cargo.lock`, or it refuses the module ("a different bindgen format than
  this binary"). A global `latest` can't match every
  project; a per-project pin can.
- The system side needs only a C linker and libc headers for native builds, which the
  `base` role already installs (`build-essential` in `group_vars/all.yml`). The
  WebAssembly target links with rust-lld, which ships in the toolchain.

**Rejected.**
- `cargo:wasm-bindgen-cli` and `cargo:` for binaryen tools: build from source on every
  install and upgrade, minutes each, for binaries the projects publish prebuilt.
- Ubuntu's `rustc`/`cargo` and `binaryen` packages: one version per release, not the
  per-project pins Rust projects expect, and they lag upstream.
- rustup from `sh.rustup.rs` directly (outside mise): a second runtime manager with its
  own PATH edits; mise already owns this layer and adds no PATH edits of its own (its
  shims are on PATH in `~/.profile`).
- `wasm-pack`: a wrapper over the same tools that the projects don't need yet; add it
  if one does.

Windows is out of scope here.
