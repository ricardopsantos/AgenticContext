# Session bootstrap (system v1.3.0)

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
path (`<root>/scripts/…`); they self-locate, no `cd` needed. The system has one
version (`<root>/VERSION`, history in `<root>/CHANGELOG.md`); this title and
every `INDEX.md` header carry it.

## 1. One call: `<root>/scripts/bootstrap.sh`
It pulls the repo (only when `<root>` is in a git clone with a remote; use
`--no-pull` on a single machine), rebuilds the three indexes, runs
`validate.sh`, lists the files to read, lists open handoffs, and prints the
stats. Then:
- **`PULL FAILED`**: if the conflict is only on `INDEX.md` / `INDEX.full.md` /
  `.summary-hashes` (derived files), run `<root>/scripts/rebuild-index.sh`,
  `git add` those paths, `git rebase --continue`. Any other conflict: stop and
  surface it. Push right after every commit so another machine's next pull sees
  it.
- **`PROBLEMS found`** (non-zero exit): fix it or surface it before task work —
  don't build on a broken index.
- **Warnings** are judgment work, not breakage. `UNCONFIRMED summary`: if you
  wrote the change this session and the summary still fits, run
  `<root>/scripts/confirm-summary.sh '<path>'`; otherwise load
  `SKILLS/meta/reconcile-summaries`. `LONG summary`, `EXPIRED 'Verify-by'`,
  `system file changed since v…`: fix when you touch that file, or tell the user.
- **`OPEN HANDOFFS`**: tell the user they exist; open one only if they resume it.

## 2. Read the listed files (one parallel batch)
Everything under `READ NEXT` in the bootstrap output: `AGENTS.md` (the rules —
don't break them; `CLAUDE.md` points to it), every `POLICIES/*.md` (the user's
extra rules: read them all and follow them exactly like `AGENTS.md`; the folder
may not exist), each folder's `SKILL.md` + `INDEX.md`, and the `[CORE]`
KNOWLEDGE docs. Open anything else only when its
summary/description matches the task. The indexes are your map — they were just
rebuilt from disk, so they cannot disagree with it.

**MEMORY is two-tier.** `MEMORY/INDEX.md` (loaded) is only a slug map: each
`MEMORY/<slug>/` folder, its finding count and a one-line scope from
`MEMORY/SLUGS.tsv`, plus any `[PROMOTE?]` entries. The per-finding catalogue
lives in `MEMORY/INDEX.full.md`, which you must **never load whole**. Search it
with `<root>/scripts/memory-find.sh <keyword> [keyword…]` (case-insensitive, all
keywords must match, max 15 hits, one trimmed line each; falls back to finding
bodies when no index line matches; slugs described as `[ARCHIVE]` only with
`--all`; `--knowledge` searches KNOWLEDGE docs the same way); open a file only when its summary matches.

**What earns `[CORE]`** (the user's call, never yours): a doc whose absence
causes a severe failure that has already recurred (a security bug shipped
several times, a rule that must hold on every task). A narrow trigger ("when you
add X") with a mild failure is not CORE: its summary already says when to read
it. Every CORE doc is paid for in every session, and the stats step shows the bill.

## 3. Stats — a user-visible step
**Tool output is not shown to the user.** The bootstrap is not done until they
can read the numbers.
1. Copy everything below the `== STATS` line of the bootstrap output, verbatim
   (no `head`/`tail`, no summarising), into your own reply text inside a code
   block, written *after* your last bootstrap tool call, not earlier in the turn
   where it gets buried.
2. If you forget, the user will say so: run `<root>/scripts/stats.sh` and paste
   it again at once.

Informational only — nothing to act on unless a number looks obviously wrong
(an empty root, a runaway file size). The last block of the output is the
**bootstrap load**: every file read at session start, with its estimated token
cost. If that total creeps up, something was tagged `[CORE]` that should not be.
Do not end the bootstrap with a dialog or picker: it covers the text above it
and the stats vanish. Ask any closing question as plain prose under the code block.

## 4. Orient in the project (optional, task-scoped)
The indexes above map `<root>`. If a task needs the *project's* layout, map it
then. If the project keeps a folder-level index of indexes (a `FOLDER-INDEX.md`
per folder), read the one you need; it carries the *why*, not just names.
Otherwise scope and keep it shallow (`tree -L 2 <path>`, or
`find <path> -maxdepth 2`), narrowed to the area you're working in. Don't map a large workspace at init:
it costs thousands of tokens and buys nothing the indexes didn't already give
you. Names, not contents.

## 5. Per task
- Before: if KNOWLEDGE didn't answer, run `memory-find.sh` with 2-3 keywords from the task (tool, host, symptom). **Always** do this before investigating a symptom from scratch, and whenever the user says "again", "still", "back", "used to work": a recurrence is usually already written down, with the fix. Open a finding only on summary match.
- After: if you learned something that meets `MEMORY/SKILL.md`'s write-criteria, write it, then rebuild the indexes. Give it a `> keywords:` line under the summary with the words a later search would use and the summary lacks: exact error text, IDs, ports, old names, synonyms (≤150 chars; searched, never loaded). Don't silently drop a qualifying finding. A new `MEMORY/<slug>/` folder also needs its `SLUGS.tsv` row: `<root>/scripts/set-slug.sh <slug> "<one-line scope>"`.
- Usage: when a MEMORY finding answers a task, run `<root>/scripts/mark-used.sh <finding> <domain>`, then rebuild.
- Adding/editing a doc: gate first with `validate.sh --content`, then rebuild. Freshness is a post-rebuild check: a full validate right after writing a file always flags a false STALE.
- Promote: if `MEMORY/INDEX.md` lists `[PROMOTE?]` entries (hand-flagged or auto), surface them to the user. Only on approval: fold into KNOWLEDGE per `MEMORY/SKILL.md`, mark the finding `[STALE]`. `[CORE]` tagging is always the user's call.
- Changing a system file (a script, a folder `SKILL.md`, `REQUIREMENTS.md`, this prompt): add the requirement + test, then `<root>/scripts/bump-version.sh <patch|minor|major> "<what changed>"` and rebuild. `validate.sh` warns until you do.

## 6. Long sessions
A chat stays cheap while its prompt cache is warm (about 1 hour) and is re-read
in full after a longer break. So when a long session is about to pause with
work unfinished, offer to write a handoff (`SKILLS/meta/session-debrief`, the
handoff step) and tell the user to start a fresh session rather than resume
this one.

## 7. Missing root
If discovery above finds nothing, stop and tell the user plainly — _"Agentic
context folder not found at or above `<cwd>`"_ — and ask for the correct
location. Don't guess, search elsewhere, or recreate the folder.

## 8. Ending-session debrief
If the session produced decisions, code changes, or discoveries worth
revisiting, load `SKILLS/meta/session-debrief` and follow it. Skip for trivial
or purely informational chats.
