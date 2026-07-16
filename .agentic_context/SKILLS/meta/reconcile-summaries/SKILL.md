---
name: reconcile-summaries
description: Resolve UNCONFIRMED-summary warnings from validate.sh — for each doc whose body changed since its summary was last confirmed, re-read the body and either rewrite the summary or confirm it via scripts/confirm-summary.sh, then rebuild. Load when validate reports UNCONFIRMED summaries, or for a periodic summary-hygiene pass.
---
# Reconcile Summaries

The scripts guarantee every doc *has* a summary; they can't judge whether it's
still *accurate* after the body changed. This skill is that judgment pass.
`validate.sh` detects the candidates mechanically (via `scripts/.summary-hashes`);
you decide each one.

## Procedure

### 1. Get the list
Run `<root>/scripts/rebuild-index.sh`, then `<root>/scripts/validate.sh`.
Collect every `UNCONFIRMED summary` path. None → done, say so.

### 2. Judge each flagged doc — one at a time
Read the doc's **body**, then its summary line, and ask: *would this one-liner
still make an agent open (or skip) this doc correctly?* The summary is a
trigger, not an abstract — judge it by routing power, not completeness.

- **Still fits** → `./scripts/confirm-summary.sh '<path>'`. Don't touch the file.
- **Doesn't fit** → rewrite the summary line in place (`> summary:` for docs,
  frontmatter `description:` for skills). Keep it one line; preserve any
  leading `[CORE]` / `[STALE]` / `[PROMOTE?]` tag unless the body change is
  exactly what invalidates the tag — flag tag changes to the user, `[CORE]`
  add/remove is always their call. Editing the line is itself the
  confirmation — no confirm call needed.

Never edit the body to match a summary you'd rather keep, and never confirm a
doc you haven't actually re-read — a wrongly-confirmed summary is invisible
until its body changes again.

### 3. Close the loop
Run `rebuild-index.sh` (picks up rewritten summaries into the indexes and the
cache), then `validate.sh` — it must end with zero UNCONFIRMED warnings.
Report to the user: confirmed-as-is vs rewritten (with the new line), and any
tag questions from step 2.

## Gotchas
- A doc flagged here may also deserve `[STALE]` instead of a better summary —
  if the body says the content is superseded, mark it stale per MEMORY rules
  rather than polishing its summary.
- `scripts/.summary-hashes` is recorded judgment, not derivable state — it
  gets committed. Don't delete it to silence warnings; that auto-confirms
  everything unseen.
