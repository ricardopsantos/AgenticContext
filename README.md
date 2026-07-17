# `.agentic_context` — agent context system

A small, portable scaffold that gives a terminal AI coding agent durable,
self-maintaining context for a large, long-running project. Plain markdown and
three shell scripts — no database, no embeddings, no plugins. Only the folder
*contents* and the `INDEX.md` files change per project; everything else (the
`SKILL.md` skeletons, the scripts, the main prompt) travels unchanged.

**Agent-agnostic by construction.** Nothing here calls a model API or depends
on a vendor SDK: it's markdown your agent reads and shell scripts it runs. If
your tool can read files and run commands, it works — Claude Code, GitHub
Copilot CLI, Codex CLI, Gemini CLI, Cursor, Aider, or whatever replaces them.
See [Using it with any agent](README+MORE.md#using-it-with-any-agent).

*What this is, why it exists, and the whole algorithm on one page. For the install command, the glossary, and the full day-to-day reference, see [README+MORE.md](README+MORE.md).*

**Index**

- [The problem](#the-problem)
- [How it works](#how-it-works)
- [The algorithm](#the-algorithm)
  - [Every session](#every-session)
  - [Per task](#per-task)
  - [After task](#after-task)
  - [Over time](#over-time)
  - [The same thing, as pseudocode](#the-same-thing-as-pseudocode)

---

## The problem

Every session your agent starts from zero. It re-greps the same code, re-reads the same files, and re-discovers the same gotchas, the ones that cost you a debug session the first time. On a big codebase that's 30k to 60k tokens burned before any new work happens.

**Why notes don't fix it.** Two failure modes. A notes file big enough to be useful is too big to paste, and it buries the one fact you need under fifty you don't. Worse, hand-maintained indexes drift the moment a file gets renamed, and the agent trusts them anyway. A confidently wrong map is worse than no map.

## How it works

**Three folders, split by behavior.** `KNOWLEDGE/` is stable reference: a small `[CORE]` subset loads every session, the rest on demand. `MEMORY/` is findings you only learn by hitting them, timestamped, never loaded upfront. `SKILLS/` is reusable procedures, loaded when the task matches. Different behavior, so different loading rules.

Here is exactly what that means at session start: a flat, small set loaded in full, and everything else left dormant on disk.

![What loads at session start: rules, the bootstrap prompt, the three INDEX.md files, and the CORE KNOWLEDGE docs, totaling about 6,500 tokens, next to everything on disk that stays dormant until a summary matches.](TLDR_session_load_diagram.svg)

**Every file describes itself.** Line 1 is the title, line 2 is a one-line `> summary:`. Skills get it free, since their frontmatter `description:` *is* the summary. That line isn't an abstract, it's a trigger: it's the only thing read to decide whether opening the file is worth it. An index entry costs about 30 tokens; the file itself costs 600 to 2,400.

One file, and the three things generated from its parts: the index entry, the fingerprint, and the staleness check.

![Anatomy of one MEMORY file: the title, the highlighted summary line, and the Used-in usage log, with arrows showing what each part becomes: an INDEX.md entry, a scripts/.summary-hashes fingerprint, and the validate.sh staleness comparison.](TLDR_file_anatomy_diagram.svg)

**The index is generated, never written.** [`rebuild-index.sh`](https://github.com/ricardopsantos/AgenticContext/blob/main/.agentic_context/scripts/rebuild-index.sh) walks the folders, scrapes each file's summary line, and rewrites all three `INDEX.md` from scratch. The summary lives inside the file it describes, which is the single source of truth, and the index is a disposable derivative. Add a file, rebuild, it appears. Delete one, rebuild, it's gone. Because the index is a pure function of disk, it *cannot* disagree with disk. That's the decision everything else hangs off.

**The safety net.** [`validate.sh`](https://github.com/ricardopsantos/AgenticContext/blob/main/.agentic_context/scripts/validate.sh) flags files missing a summary, summaries spilling to a second line, files sitting where the index script can't see them, and any index older than what it describes. Truthfulness is checked, not hoped for.

**Promotion, by evidence.** Findings start in MEMORY because at discovery you can't tell a local quirk from a project-wide fact. Each finding records the domains it gets used in, and at three distinct domains the rebuild nominates it. The test is generality rather than frequency: a daily gotcha inside one module stays put, while a rare but project-wide fact moves up. A human approves the move, because promotion adds to the always-loaded core, and that core only works while it stays small.

**Why it scales.** On the deployment we measured, the knowledge folder is 214k tokens and no longer fits in a context window at all. Per-session load: **~6,500 tokens, flat.** Each new document adds ~47 tokens to a session, because the index grows by one line, not by the document. Awareness of everything at ~2% of its cost, and that ratio holds as the folder grows for years. At that scale (33 repos, ~4.6M tokens of source) it works out to ~78% cheaper orientation, with break-even on the first reused fact.

**The honest limit.** A script can guarantee every file has a summary. It can't judge whether that summary is still true after the body changes. So the rebuild fingerprints summary and body separately, and validation warns `UNCONFIRMED` when they drift, flagging that a human judgment is due instead of faking one. Automate what's mechanical, detect the rest.

Two of those states, STALE and UNCONFIRMED, aren't exclusive to MEMORY or to KNOWLEDGE — both apply to either side alike. This is what that looks like as a Venn diagram: MEMORY-only states on the left, KNOWLEDGE-only states on the right, and the two shared states sitting in the overlap.

![Finding and doc lifecycle as a Venn diagram: MEMORY-only states (MEMORY, PROMOTE?) on the left, KNOWLEDGE-only states (KNOWLEDGE, CORE) on the right, and the shared states STALE and UNCONFIRMED in the overlap, with promotion as the one arrow crossing between the two lobes.](TLDR_states_diagram.svg)

No database, no embeddings, no plugins. Three folders, three shell scripts, plain markdown.

---

## The algorithm

*One rule underneath all of it: **files are the source of truth, indexes are derived.** The agent reads the map but never draws it.*

The steps below as a sequence diagram, showing who calls whom: the agent, the
scripts, disk, and the human who has the only vote on promotion and staleness.

![The algorithm as a sequence diagram across four lifelines (Agent, Scripts, Disk, Human), grouped into four phases (every session, per task, after task, over time), with numbered circles matching the steps below.](TLDR_sequence_diagram.svg)

### Every session

0. **You start it — paste the session bootstrap.** Everything below only happens because you open every agent session by pasting [MAIN_PROMPT.md](https://github.com/ricardopsantos/AgenticContext/blob/main/MAIN_PROMPT.md) (or pointing your tool's auto-loaded rules at it). The prompt then finds the root on its own: walk up from the working directory and match the context folder by what it *contains* (`scripts/rebuild-index.sh` + `KNOWLEDGE/`), never by name — nothing hardcoded, so the folder can be called anything. Then it reads the rules (`AGENTS.md`).
1. **Self-heal first.** Rebuild the indexes from disk *before* reading them. A map regenerated from the territory can't be out of date.
2. **Validate.** If a file lost its summary, or sits where the script can't see it, fail loudly now. Don't build on a broken index.
3. **Load small.** The rules file, the three index one-liners, and the `[CORE]` docs. Nothing else. ~6,500 tokens, flat, forever.

### Per task

4. **Scan, don't open.** Match the task against the index one-liners. KNOWLEDGE first; consult MEMORY only if KNOWLEDGE didn't answer.
5. **Open on match only.** A summary is a trigger, not an abstract. It's the sole basis for deciding whether the file is worth its 600 to 2,400 tokens.
6. **Record the hit.** When a finding answers a task, append that task's domain to its `Used in:` line. This is what turns promotion into evidence.

### After task

7. **Write what you learned**, but only if it's non-obvious, will recur, and is too narrow for KNOWLEDGE. Never official-doc facts, one-off context, or secrets. One finding, one file, timestamped, summary on line 2.
8. **Rebuild.** The new finding appears in the index because it's on disk, not because anyone listed it.

### Over time

9. **Promote on evidence.** At three or more distinct domains in `Used in:`, the rebuild nominates a finding. The test is generality, not frequency. A human approves, because promotion grows the always-loaded core and that core only works while it's small. Once folded into KNOWLEDGE, the finding is marked `[STALE]`.
10. **Supersede, never delete.** The replacement goes in, the old summary gets `[STALE]`, and it drops to a "skip unless auditing" tail. You keep the trail of what you once believed.
11. **Re-confirm meaning.** Bodies drift from summaries. Fingerprint both; when they diverge, warn `UNCONFIRMED` and make a human re-read and decide.

### The same thing, as pseudocode

```
on session_start:
    root = discover_root()          # find it, don't assume it
    read(AGENTS.md)                 # the rules
    rebuild_index()                 # self-heal BEFORE reading
    if not validate(): stop()       # never build on a broken map
    load(CORE_docs + INDEX summaries)

on task:
    hits = scan(INDEX one-liners, task)          # ~30 tokens each
    for doc in hits where summary matches task:
        open(doc)                                # 600-2,400 tokens
        if doc in MEMORY and doc answered task:
            doc.used_in += task.domain
            rebuild_index()

on task_end:
    if learned(x) and non_obvious(x) and recurs(x) and too_narrow_for_KNOWLEDGE(x):
        write(MEMORY/<slug>/<timestamp>_<topic>.md, summary=line_2(x))
        rebuild_index()

on rebuild_index:                   # the load-bearing function
    for folder in [KNOWLEDGE, MEMORY, SKILLS]:
        INDEX[folder] = [scrape_summary(f) for f in walk(folder)]
        # pure function of disk => cannot disagree with disk
    fingerprint(summary, body)      # for staleness detection

on promotion_check:                 # inside rebuild
    if count(distinct(finding.used_in)) >= 3:
        nominate(finding)           # nominate; never decide
        # human approves -> fold into KNOWLEDGE, mark finding [STALE]

on validate:
    assert every file has a one-line summary
    assert no file is invisible to the index script
    assert every INDEX newer than what it describes
    warn UNCONFIRMED where body_hash drifted past confirmed_summary_hash
```

---

*The long-form story: [The Index That Can't Lie](https://ricardojpsantos.medium.com/the-index-that-cant-lie-how-we-gave-claude-code-a-memory-that-maintains-itself-614340266577) on Medium.*
