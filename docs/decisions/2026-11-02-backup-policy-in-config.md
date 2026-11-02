---
status: accepted
decided_by: agent, proposed in answer to the user's request to back up the hub and the home folder
source: session 2026-11-02-hub-setup
---
# What backup-snapshot copies is configuration outside this repository

**Decision.** `backup-snapshot` reads its sources from `~/.config/backup-snapshot/sources`
(`source|path inside a snapshot|filter`), each with an optional file of rsync filter
rules beside it. On the workstation, chezmoi links that folder to the owner's private
notes, where the list now also covers the notes themselves and an allowlist of the home
folder: what can't be re-obtained, never secrets. The script refuses to run without the
file, and a run resumed from `.partial` drops what the filters now exclude
(`--delete-excluded`).

**Why.** The script was public but its list was the machine's own policy, and the owner
wants to add the home folder and drop folders not worth keeping, which means naming
private paths. Filter rules handle both the allowlist and exclusions deep inside a kept
folder. Tested against a scratch backup root: two snapshots, unchanged files hard-linked
between them, copies identical to their sources, no credentials copied.

**Rejected.** Keeping the list in the script, which puts personal paths in a public repo.
A source per home path, which can't express "everything here except".
