---
status: accepted
decided_by: user (Rust belongs in machine-setup); form chosen in session
source: 2026-11-08-rust-wasm-toolchain-via-mise
---
<!-- Generated from the vault note 2026-11-08-wasm-bindgen-and-wasm-opt-come-from-mise-pinned-per-project; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

On Linux, the global mise config (`home/dot_config/mise/config.toml`) adds the Rust and WebAssembly tools to the per-user runtimes of `2026-10-13-mise-user-runtimes`:

- `wasm-bindgen` (with `wasm-bindgen-test-runner`) from its GitHub releases (`github:wasm-bindgen/wasm-bindgen`): static musl binaries, which mise checks against GitHub's asset digest and the release's artifact attestations. The aqua registry has no entry for it.
- `wasm-opt` from binaryen through the aqua registry (`aqua:WebAssembly/binaryen`), checked against GitHub's asset digest. The release is the whole toolkit (about 110 MB compressed); the other `wasm-*` tools come with it.

Projects pin their own versions: `wasm-bindgen` and binaryen in the project's `mise.toml`. The global entries are only defaults for directories that pin nothing.

Rust itself: `2026-11-08-rust-comes-from-mise-and-yields-to-rust-toolchain-toml`. Windows is out of scope here.

## Why
- The `wasm-bindgen` CLI must be the same version as the `wasm-bindgen` crate in the project's `Cargo.lock`, or it refuses the module ("a different bindgen format than this binary"). A global `latest` can't match every project; a per-project pin can.

## Rejected
- `cargo:wasm-bindgen-cli` and `cargo:` for binaryen tools: build from source on every install and upgrade, minutes each, for binaries the projects publish prebuilt.
- Ubuntu's `rustc`/`cargo` and `binaryen` packages: one version per release, not the per-project pins Rust projects expect, and they lag upstream.
- `wasm-pack`: a wrapper over the same tools that the projects don't need yet; add it if one does.
