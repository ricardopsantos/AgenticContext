# Session bootstrap

Root `<root>`: the context folder at or above the working directory —
identified by **what it contains**, not by its name, so it works whatever the
folder is called (`.agentic_context`, `agentic_context`, `my_context`, …).
**Discover it, don't assume it** — run this once and use the result as
`<root>` for the rest of the session:

```bash
(D="$PWD"; while [ "$D" != / ]; do
   while IFS= read -r C; do
     [ -f "$C/scripts/rebuild-index.sh" ] && [ -d "$C/KNOWLEDGE" ] && { echo "$C"; exit 0; }
   done <<INNER
$(find "$D" -maxdepth 1 -type d 2>/dev/null)
INNER
   D=$(dirname "$D")
 done; echo "NOT FOUND"; exit 1)
```

Bootstrap + load order only — meaning lives in each `SKILL.md`. Run scripts by
path (`<root>/scripts/…`); they self-locate, no `cd` needed.

## 1. Rules (always)
Read `<root>/AGENTS.md` (`CLAUDE.md` points to it). Don't break it.

## 2. Self-heal the indexes
Run `<root>/scripts/rebuild-index.sh` so all three `INDEX.md` match the files on
disk, then `<root>/scripts/validate.sh` (full check). If validate exits
non-zero, fix it or surface it before doing task work — don't build on a
broken index.

When adding/editing a doc later: gate first with `validate.sh --content`, then
rebuild. Freshness is a post-rebuild check — a full validate right after
writing a file always flags a false STALE.

`UNCONFIRMED summary` warnings are judgment work, not breakage:
- **You wrote the change this session and know the summary still fits** (the
  common case — writing a file then editing it re-flags it): just run
  `<root>/scripts/confirm-summary.sh '<path>'`.
- **Otherwise** (didn't write it, or unsure): load `SKILLS/meta/reconcile-summaries`.

## 3. Stats
Run `<root>/scripts/stats.sh` and skim the output (folder/file counts, sizes,
biggest/smallest). Informational only — nothing to act on unless a number
looks obviously wrong (e.g. an empty root, a runaway file size).

## 4. Load policy — one rule, three folders
Read each folder's `SKILL.md` + `INDEX.md` (they're small). Load `[CORE]`
KNOWLEDGE docs now; open anything else only when its summary/description
matches the task. The indexes are your map — they're rebuilt from disk in
step 2, so they cannot disagree with it.

## 5. Orient in the project (optional, task-scoped)
The indexes above map `<root>`. If a task needs the *project's* layout, map it
then — scoped and shallow (`tree -L 2 <path>`, or `find <path> -maxdepth 2`),
narrowed to the area you're working in. Don't map a large workspace at init:
it costs thousands of tokens and buys nothing the indexes didn't already give
you. Names, not contents.

## 6. Per task
- Before: check `MEMORY/INDEX.md` for matching entries; open a finding only if KNOWLEDGE didn't answer.
- After: if you learned something that meets `MEMORY/SKILL.md`'s write-criteria, write it, then rebuild the indexes. Don't silently drop a qualifying finding.
- Usage: when a MEMORY finding answers a task, append that task's domain to its `**Used in:**` line, then rebuild.
- Promote: if `MEMORY/INDEX.md` shows `[PROMOTE?]` entries (hand-flagged or auto), surface them to the user. Only on approval: fold into KNOWLEDGE per `MEMORY/SKILL.md`, mark the finding `[STALE]`. `[CORE]` tagging is always the user's call.

## 7. Missing root
If discovery above finds nothing, stop and tell the user plainly — _"Agentic
context folder not found at or above `<cwd>`"_ — and ask for the correct
location. Don't guess, search elsewhere, or recreate the folder.

## 8. Ending-session debrief
If the session produced decisions, code changes, or discoveries worth
revisiting, load `SKILLS/meta/session-debrief` and follow it. Skip for trivial
or purely informational chats.
