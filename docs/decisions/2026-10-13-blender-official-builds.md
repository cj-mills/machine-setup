---
status: accepted
decided_by: not recorded
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
<!-- Generated from the vault note 2026-10-13-blender-official-builds; don't edit here. Edit the note in the hub's vault and export it again with tools/vault_export.py. -->

# Blender from official builds under /opt/blender

Blender: official builds (not Flathub) under `/opt/blender`, one row per release in `blender_versions` with `blender-<series>` commands and a default `blender`; currently 5.2 LTS only, since projects target the latest LTS Python API. Releases are pinned by SHA-256 verified across three mirrors (`scripts/blender-pin.sh`); download.blender.org rejects scripted clients. API-heavy and agentic pipelines use the PyPI `bpy` wheel in a project-owned conda environment (isolated via cjm-substrate), version-matched to the installed Blender.
