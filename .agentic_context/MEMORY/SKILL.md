---
name: memory
description: Persistent store for session-learned facts that don't belong in active context — gotchas, quirks, fixes worth keeping across sessions but not yet a skill or knowledge doc.
---
# Memory
## Purpose
Session findings, written at discovery, consulted on demand. Never loaded upfront.
## Discovery
- Two tiers, both derived. **`MEMORY/INDEX.md`** (loaded at init) is a slug map: folder, finding count, scope (from `MEMORY/SLUGS.tsv`) and `[PROMOTE?]` entries. **`MEMORY/INDEX.full.md`** holds every finding's `> summary:` line and is never loaded whole.
- Search with `scripts/memory-find.sh <kw…>` (AND, case-insensitive, max 15 hits) when KNOWLEDGE didn't answer or before investigating a symptom; open a finding only on summary match. No index line matches → it searches the finding bodies and marks those hits `[body]`.
- A slug whose `SLUGS.tsv` description starts with `[ARCHIVE]` (bulk history) is skipped unless you pass `--all`; the output says how many hits were hidden.
- New `MEMORY/<slug>/` folder → in the same step run `scripts/set-slug.sh <slug> "<one-line description>"` (it keeps `MEMORY/SLUGS.tsv` sorted and tab-clean; rebuild and validate warn if the row is missing).
## Write when
Non-obvious + will recur + too narrow for KNOWLEDGE. Never: official-doc facts, one-off context, secrets.
## Format (line 2 summary mandatory)
```
# <Topic>
> summary: <finding + why it matters>
> keywords: <term>, <term>, "<exact error text>"   (words a future search would use that the summary lacks)

**Discovered:** YYYY-MM-DD
**Context:** <where found>
**Used in:** <domain>, <domain>
**Verify-by:** YYYY-MM-DD      (optional: a volatile fact, e.g. a port, host or URL, to re-check by then)
**Superseded-by:** <file>      (only on a [STALE — superseded…] finding)
**Corrects:** <file>           (only on the replacing finding: back-link)

## Finding / ## Details / ## Caveats
```
Summary: one line, at most 300 characters (`validate.sh` warns); detail goes in the body. `Used in` starts absent; add it the first time the finding answers a task. `Superseded-by` / `Corrects` are optional and appear only on a supersede pair (below). Once `Verify-by` has passed, `validate.sh` warns until you re-check the fact and move the date, or mark the finding `[STALE`. A `[body]` search hit means the summary missed the words used: add them to its `> keywords:` line (the search prints one ready to paste). Keywords are searched, never loaded; keep them ≤150 characters. Older findings may still use a `**Keywords:**` body line; it works the same.
After writing/superseding, run `./scripts/rebuild-index.sh`.
## Usage tracking (feeds promotion)
- When a finding answers a task, run `scripts/mark-used.sh <finding> <domain>` (it creates or extends the `**Used in:**` line, never duplicating; prefer an existing SKILLS category or MEMORY group name so domains stay consistent), then rebuild.
- The rebuild script auto-tags an index entry `[PROMOTE? auto — used in N domains]` at ≥3 distinct domains. Generality proven by use across domains, not by judgment or frequency.
## Supersede / Promote
- Supersede: new file in same slug; prefix the old file's summary `[STALE — superseded by <file>]` (the index moves it to a superseded tail section and prints `-> <replacement>`), add `**Superseded-by:** <file>` to the old finding and `**Corrects:** <old file>` to the new one. `validate.sh` warns (never fails) when a `[STALE — superseded…]` finding has no `Superseded-by:`, the target is missing, or the target lacks the `Corrects:` back-link. Other `[STALE` wording (fixed, closed out, promoted, folded) is not a supersede and is not checked. Never delete.
- Promote: candidates surface two ways — hand-prefix the summary `[PROMOTE?]` (judgment) or the auto-tag from usage tracking (evidence). Either way the user confirms the move into KNOWLEDGE; promotion does NOT imply `[CORE]` — that tag is always a separate human decision. See README for the full test + examples.
- Already covered? If a KNOWLEDGE doc already holds the fact, don't promote — fold anything new into that doc and mark the finding `[STALE]`. One source of truth.
- Rejected? Prefix the summary `[REVIEWED <date> — not for promotion, …]` with the reason. Without it a finding at ≥3 used-in domains is re-flagged by every rebuild, so a settled "no" gets re-litigated each session.

### Summary-prefix keywords
`[STALE`, `[PROMOTE?`, `[REVIEWED` are read by `rebuild-index.sh` at the **start** of the summary. Each may carry an explanation before the closing bracket (`[STALE — superseded by <file>]`), so write the keyword first and never rely on a bare `]` terminating it.

## Nesting (supported, use sparingly)
The index script recurses at any depth, so `MEMORY/<slug>/<sub-slug>/<file>.md` is valid. But MEMORY files are ordered by discovery date (`YYYYMMDD_*` prefix) — chronology already groups related findings. Only cluster into subfolders when a slug crosses ~20 files OR a genuinely separable sub-domain emerges. Prefer the timeline shape over topical folders.
