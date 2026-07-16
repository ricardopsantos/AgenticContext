---
name: memory
description: Persistent store for session-learned facts that don't belong in active context — gotchas, quirks, fixes worth keeping across sessions but not yet a skill or knowledge doc.
---
# Memory
## Purpose
Session findings, written at discovery, consulted on demand. Never loaded upfront.
## Discovery
- Live list is **`MEMORY/INDEX.md`** (entries = each finding's `> summary:` line).
- At init know names only; consult a slug's entries when relevant AND KNOWLEDGE didn't answer; open a finding only on summary match.
## Write when
Non-obvious + will recur + too narrow for KNOWLEDGE. Never: official-doc facts, one-off context, secrets.
## Format (line 2 summary mandatory)
```
# <Topic>
> summary: <finding + why it matters>

**Discovered:** YYYY-MM-DD
**Context:** <where found>
**Used in:** <domain>, <domain>

## Finding / ## Details / ## Caveats
```
`Used in` starts absent; add it the first time the finding answers a task.
After writing/superseding, run `./scripts/rebuild-index.sh`.
## Usage tracking (feeds promotion)
- When a finding answers a task, append that task's domain to its `**Used in:**` line (comma-separated, no duplicates; prefer an existing SKILLS category or MEMORY group name so domains stay consistent), then rebuild.
- The rebuild script auto-tags an index entry `[PROMOTE? auto — used in N domains]` at ≥3 distinct domains. Generality proven by use across domains, not by judgment or frequency.
## Supersede / Promote
- Supersede: new file in same slug; prefix the old file's summary `[STALE]` (the index moves it to a superseded tail section) and note the replacement in its Caveats. Never delete.
- Promote: candidates surface two ways — hand-prefix the summary `[PROMOTE?]` (judgment) or the auto-tag from usage tracking (evidence). Either way the user confirms the move into KNOWLEDGE; promotion does NOT imply `[CORE]` — that tag is always a separate human decision. See README for the full test + examples.
- Already covered? If a KNOWLEDGE doc already holds the fact, don't promote — fold anything new into that doc and mark the finding `[STALE]`. One source of truth.

## Nesting (supported, use sparingly)
The index script recurses at any depth, so `MEMORY/<slug>/<sub-slug>/<file>.md` is valid. But MEMORY files are ordered by discovery date (`YYYYMMDD_*` prefix) — chronology already groups related findings. Only cluster into subfolders when a slug crosses ~20 files OR a genuinely separable sub-domain emerges. Prefer the timeline shape over topical folders.
