---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# Windows moves to its own drive as a fresh install

Windows moves to its own drive (second 990 PRO) as a fresh install: it is now a development platform (Unity/Unreal, Windows AI stack), not just a test target, and 500 GB on the shared drive is too small. One OS per drive also gives each its own ESP, so neither OS's updates or reinstalls touch the other. Rejected: a Windows data drive alongside the shared C:, and growing C: into the old Storage partition.
