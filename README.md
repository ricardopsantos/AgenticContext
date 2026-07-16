# `.agentic_context` — agent context system

A small, portable scaffold that gives an AI coding agent (Claude Code) durable,
self-maintaining context for a large, long-running project. Plain markdown and
three shell scripts — no database, no embeddings, no plugins. Only the folder
*contents* and the `INDEX.md` files change per project; everything else (the
`SKILL.md` skeletons, the scripts, the main prompt) travels unchanged.

---

## Install

From your project root:

```bash
curl -fsSL https://raw.githubusercontent.com/ricardopsantos/AgenticMemory/main/install-claude-science.sh | bash
```

Needs only `curl` and `tar`. It creates `.agentic_context/` (skeleton, scripts,
meta-skills, dummy example docs marked "delete me"), points the bootstrap
prompt's `Root:` path at your project, installs the `/enrich-prompt` wrapper
for Claude Code, then builds the indexes and validates the install. It refuses
to overwrite an existing install; options:

```bash
curl -fsSL <same-url> | bash -s -- /path/to/project --force
```

To install from a local clone instead: `./install-claude-science.sh`, or the
offline `./install.sh <target-dir>`.

**Read the story:** the design and its evolution are written up in
[`Articles/`](Articles/) (Part 1: the derived index; Part 2: the hardened
safety net, auto-promotion, semantic staleness, and real token numbers), with
a short version in [`Auxiliar/TLDR.md`](Auxiliar/TLDR.md) and the measurements
in [`Auxiliar/TOKEN_STUDY.md`](Auxiliar/TOKEN_STUDY.md).

---

## The problem this solves

An agent only knows what's in its context window. On a big project that grows
over months, two things go wrong:

1. **Context doesn't persist.** Findings discovered in one session are gone by
   the next unless something stores them.
2. **Stored context rots.** The moment you keep a hand-maintained list of "what
   we know," it drifts out of sync with reality — files get renamed, added, or
   deleted and the list lies. A confidently-wrong index is worse than none.

The whole design is a response to #2. Almost every choice here exists to make
drift *impossible by construction* rather than *avoided by discipline*.

---

## The three folders

Context is split by *how it behaves*, not by topic:

- **`KNOWLEDGE/`** — static, authoritative reference. Ground truth that rarely
  changes (architecture, product maps, glossaries). Treated as fact. Has a small
  always-loaded core (`[CORE]`).
- **`MEMORY/`** — session-learned findings. Non-obvious gotchas/quirks/fixes
  discovered while working. Narrow, timestamped, written at discovery time.
  Never loaded upfront — only dug up on demand.
- **`SKILLS/`** — how-to guides. Reusable procedures (build/release, Swift
  concurrency patterns, testing strategy).

Reference vs. findings vs. procedures. Keeping them separate is what lets each
have its own load policy.

---

## The core idea: tiered, lazy, self-describing

The agent should *not* load everything every session — that bloats context and
drowns the relevant in the irrelevant. Instead:

- At session start it loads only **small index files** plus a tiny always-on
  core. Everything else is loaded **on demand**, only when relevant.
- Each item **describes itself** in one line. KNOWLEDGE and MEMORY docs carry a
  `> summary:` line as line 2; skills use their frontmatter `description:`.
  That one line is the trigger the agent reads to decide whether to open the
  full file.

This is the "load descriptions, not just names" principle: a bare filename like
`init-order.md` is a weak signal; a one-line summary lets the agent reliably
decide what to dig into.

### `[CORE]` and `[PROMOTE?]` tags

- `[CORE]` in a KNOWLEDGE summary = always load this at session start (it's
  relevant to almost every task). Keep this set *tiny* — it's the one thing that
  loads unconditionally.
- `[PROMOTE?]` in a MEMORY summary = this finding looks broadly applicable and
  is a candidate to graduate into KNOWLEDGE (see "Promotion" below).

---

## Why the index is *derived*, never hand-written

The single most important decision. The summary lives **inside each file** (the
source of truth). The `INDEX.md` files are **generated** from those summaries by
a script. The agent reads the index; it never authors it.

Consequence: the index is a pure function of what's on disk, so it *cannot*
disagree with reality. Add a doc → rebuild → it appears. Delete a doc → rebuild
→ it's gone. Edit a summary → rebuild → the index updates. The index is
disposable; one command recreates it perfectly. This is what kills the drift
problem at the root instead of asking a human to remember to keep a list current.

The rejected alternative — "let the agent write entries straight into the
index" — feels convenient but reintroduces drift: the summary then exists only
in the index, can't be regenerated, and won't update when the doc changes.

---

## `scripts/`

- **`rebuild-index.sh`** — regenerates all three `INDEX.md` from the source
  summaries (`> summary:` lines for docs, frontmatter `description:` for skills).
  Each entry also gets an estimated context cost (`~N tok`, size ÷ 4), and MEMORY
  entries with ≥3 distinct `**Used in:**` domains are auto-tagged
  `[PROMOTE? auto]`. Run after any content change; also run on session init as a
  self-heal.
- **`validate.sh`** — read-only integrity check; exits non-zero on problems.
  Flags: docs with missing/empty/multi-line `> summary:`, skills missing
  `description:`, malformed `**Used in:**` lines, stray files the index script
  can't see (docs at a folder root, skill folders without a `SKILL.md`), and any
  `INDEX.md` older than the content it describes. `--content` runs only the
  content checks — use it as a gate right after writing a file, since the
  freshness check would flag a false STALE before the next rebuild. The full
  run also *warns* (never fails) on semantic staleness: any doc whose body
  changed since its summary was last confirmed (see below).
- **`confirm-summary.sh <file>…`** — records the judgment "I re-read this doc
  and its summary still fits" after a body-only edit, so validate stops
  flagging it. Editing the summary line itself confirms implicitly.

Both `cd` to the repo root first, so they work from anywhere and always write
indexes at the root.

**Known limit, and how it's handled:** the scripts can't judge whether a
summary is still *accurate* — accuracy needs a read. But they can detect when
that judgment is *due*: `rebuild-index.sh` keeps `scripts/.summary-hashes`
(per file: summary-line hash + body hash; refreshed when a file is new or its
summary changes, kept when only the body changes), and `validate.sh` warns
`UNCONFIRMED` for any doc whose body drifted past its last-confirmed summary.
Resolving the warning is the judgment step: re-read and either rewrite the
summary or run `confirm-summary.sh` (procedure:
`SKILLS/meta/reconcile-summaries`). The cache is recorded judgment — commit
it; deleting it silently re-confirms everything.

---

## How a session runs (see `MAIN_PROMPT.md`)

Paste `MAIN_PROMPT.md` at the start of a Claude Code session. It is
**bootstrap + load order only** — it says *when* to read things; what each folder
*is* lives in that folder's `SKILL.md`. Flow:

1. Read the rules (`AGENTS.md`).
2. `tree` the workspace — names, not contents.
3. Self-heal: run `rebuild-index.sh`, then `validate.sh` (full check).
4. Load policy: read the three small indexes; always-load `[CORE]`; everything
   else lazy on summary match.
5. Per task: check MEMORY before; after, write qualifying findings, append the
   task's domain to any finding's `**Used in:**` line that answered, rebuild.
6. Drift check: if anything disagrees with `tree`, trust disk and rebuild.

**Division of labor:** rules that describe a folder's own mechanics live in its
`SKILL.md` (they travel with the folder); rules about session orchestration live
in the main prompt (it's what actually runs each session). Definitions are
written *once* — duplicating them across prompt and SKILL.md just creates a
second copy to keep in sync.

---

## Adding things

- **KNOWLEDGE doc:** drop a `.md` in the right family; line 1 `# Title`, line 2
  `> summary: …` (prefix `[CORE]` if always-load); run `rebuild-index.sh`.
- **MEMORY finding:** `MEMORY/<slug>/YYYYMMDD_HHMMSS_<sub-slug>.md` with a
  `> summary:` line; run `rebuild-index.sh`. Supersede by adding a new file and
  marking the old stale in its Caveats — never delete.
- **Skill:** `SKILLS/<category>/<name>/SKILL.md` with frontmatter `name:` +
  `description:` (the description is what the index shows — make it
  trigger-worthy); run `rebuild-index.sh`.

---

## Meta skills — the framework about itself

`SKILLS/meta/` holds skills that operate on the context system rather than the
project:

- **`improve-prompt`** — turn a raw prompt into an enriched one: rewrite for
  clarity, match it against the three indexes, inline what fits a ~4k-token
  budget (bigger matches become load instructions), show the result, execute
  only on confirmation. A thin `/enrich-prompt` wrapper in `.claude/skills/`
  invokes it; all logic stays here so it travels with the folder.
- **`reconcile-summaries`** — the judgment pass that resolves `UNCONFIRMED
  summary` warnings from `validate.sh`: re-read each flagged doc, rewrite the
  summary or confirm it via `confirm-summary.sh`.

---

## Promotion: MEMORY → KNOWLEDGE

### What it is

Moving a finding *up* from MEMORY into KNOWLEDGE once it has proven it deserves
to always be available. A finding starts in MEMORY because, at discovery time,
you can't yet tell whether it's a one-off quirk or a fundamental fact about the
project. Promotion is the moment you decide it's the latter — so the agent stops
having to dig it up and instead just always has it.

The point of the move: MEMORY is only consulted on demand; KNOWLEDGE (especially
`[CORE]`) is loaded every session. Promoting puts a fact where it's always in
context.

### The test: generality, NOT frequency

The intuitive rule — "I've used this a lot, so promote it" — is wrong. The right
question is **"does this apply to almost any task here, or just one corner of the
project?"** Breadth of applicability, not how often you've hit it. This breaks
the frequency intuition in both directions:

- **Frequent but narrow → stays in MEMORY.**
  *Example:* "The payments SDK must be initialised before the API key is set."
  You might hit this constantly, but it only matters inside the payments module.
  Promote it and you'd force that trivia into context for every unrelated task —
  exactly the bloat the tiered system exists to prevent.

- **Rare but broad → should be promoted.**
  *Example:* "Every service repo clones under `~/Code/<org>/`." You touch
  this rarely, but it's true project-wide and useful from almost any task. When
  you do need it, it should already be loaded, not dug up.

### Why a human confirms it (not automatic)

Promotion adds to the always-loaded core, and that core only works while it stays
small. If the agent auto-promoted anything it used a few times, the core would
quietly bloat until the lean-startup-load benefit is gone. So the flow splits
*flagging* from *deciding*: a candidate gets flagged either by hand (prefix its
summary with `[PROMOTE?]`) or automatically — `rebuild-index.sh` tags any MEMORY
finding whose `**Used in:**` line spans ≥3 distinct domains. Either way, the
actual move is a deliberate human checkpoint that guards the core against creep.

### How to actually do it

1. Copy the finding's content into the correct `KNOWLEDGE/<family>/` as a proper
   doc, with its own `> summary:` line (add `[CORE]` only if it should load every
   session).
2. Mark the original MEMORY file stale in its Caveats (same supersede rule MEMORY
   uses everywhere) — don't delete it.
3. Run `./scripts/rebuild-index.sh` so both indexes update.

---

## Open questions / future improvements

Nothing currently open. Resolved since first written:

- **Semantic staleness** — `rebuild-index.sh` keeps a summary/body hash cache,
  `validate.sh` warns `UNCONFIRMED` when a body drifts past its confirmed
  summary, and `SKILLS/meta/reconcile-summaries` is the judgment pass that
  resolves the warnings (rewrite or `confirm-summary.sh`).
- **Index-entry → missing-file check** — `validate.sh` now catches strays and
  stale indexes.
- **Auto-promotion signal** — `**Used in:**` tracking + auto `[PROMOTE?]` at
  ≥3 distinct domains.
- **`AGENTS.md` tension** — stated as "think deeply; write briefly".

---

## License

[MIT](LICENSE) — use it, fork it, ship it. Attribution appreciated but the
license doesn't require your gratitude, only the copyright notice.
