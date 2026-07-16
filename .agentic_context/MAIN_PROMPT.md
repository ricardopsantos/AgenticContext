# Session bootstrap 

Root `<root>`: `.agentic_context` (this repo's `.agentic_context/` folder). Bootstrap + load order only — meaning lives in each `SKILL.md`. Run scripts by path (`<root>/scripts/…`); they self-locate, no `cd` needed.

## 1. Rules (always)
Read `AGENTS.md` (`CLAUDE.md` points to it). Don't break it.

## 2. Map — names not contents
`tree -L 3` once (no `tree`? `find . -maxdepth 3` works). Don't read doc/memory contents yet.

## 3. Self-heal the indexes
Run `<root>/scripts/rebuild-index.sh` so all three `INDEX.md` match the files on disk, then `<root>/scripts/validate.sh` (full check — content + index-freshness drift).
When adding/editing a doc later: gate first with `validate.sh --content`, then rebuild. Freshness is a post-rebuild check — a full validate right after writing a file always flags a false STALE.
If validate reports `UNCONFIRMED summary` warnings, that's judgment work, not breakage — load `SKILLS/meta/reconcile-summaries` and resolve them.

## 4. Load policy — one rule, three folders
At init read each folder's `SKILL.md` + `INDEX.md` (they're small). Load `[CORE]` KNOWLEDGE docs now; open anything else only when its summary/description matches the task.

## 5. Per task
- Before: check `MEMORY/INDEX.md` for matching entries; open a finding only if KNOWLEDGE didn't answer.
- After: if you learned something that meets `MEMORY/SKILL.md`'s write-criteria, write it, then rebuild the indexes. Don't silently drop a qualifying finding.
- Usage: when a MEMORY finding answers a task, append that task's domain to its `**Used in:**` line, then rebuild.
- Promote: if `MEMORY/INDEX.md` shows `[PROMOTE?]` entries (hand-flagged or auto), surface them to the user. Only on approval: fold into KNOWLEDGE per `MEMORY/SKILL.md`, mark the finding `[STALE]`. `[CORE]` tagging is always the user's call.

## 6. Drift
If any INDEX/SKILL disagrees with `tree`, trust disk and run `<root>/scripts/rebuild-index.sh`.

## 7. Missing root
If the `<root>` path above doesn't exist, stop and tell the user plainly — _"Agentic context folder not found at `<path>`"_ — and ask for the correct location. Don't guess, search elsewhere, or recreate the folder.

## 8. Ending-session debrief

At the end of every coding session with real work, answer these six questions and save the result as `MEMORY/session-final/YYYYMMDD_HHMMSS.md`.

Use the standard MEMORY format:

```markdown
# Session close — YYYY-MM-DD
> summary: <one-line synthesis of the biggest risk or takeaway>

**Session:** YYYY-MM-DD
**Used in:** session-retrospective
<!-- Add domains only if this file later answers a future task -->

## Q1 — What are you least confident about right now?
...

## Q2 — What’s the biggest thing the user is missing about this situation?
...

## Q3 — What insight from today did the user NOT ask to be stored, but should have been?
...

## Q4 — If this breaks in 3 months, what is the most likely reason?
...

## Q5 — If you could add one unrequested, industry-leading feature, what would it be?
...

## Q6 — What could the user have done differently to make this session more efficient?
...
```

Only create the file if the session produced decisions, code changes, or discoveries worth revisiting. Skip trivial or purely informational chats.
