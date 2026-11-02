---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# Chrome on Windows installs from Google's signed enterprise MSI

Chrome on Windows installs from Google's enterprise MSI, accepted only with a valid Google LLC Authenticode signature, instead of winget: Google replaces the file at its unversioned URL with every release, so winget's pinned checksum fails (`0x8A150011`) until the manifest catches up. That failed the real install's first bootstrap (Google published 156.0.8078.73 at 20:32 UTC; the manifest still had .48). Chrome updates itself afterwards, as on Linux (Google's apt repo). Of the other winget packages, only Steam's installer URL is unversioned, and that installer rarely changes; left on winget.
