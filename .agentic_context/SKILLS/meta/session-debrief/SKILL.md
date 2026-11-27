---
name: session-debrief
description: End-of-session retrospective — answer seven fixed questions and save them as a MEMORY finding under session-final/. Load at the end of any session that produced decisions, code changes, or discoveries worth revisiting; skip for trivial or purely informational chats.
---
# Session Debrief

The closing ritual for a real working session. Seven questions, asked the same
way every time, saved where a future session can find them. The value is in
the fixed set — the questions are chosen to surface what a normal summary
hides (fragility, unspoken insight, wasted effort), so don't improvise
substitutes or skip the uncomfortable ones.

## When to run

At the end of a session that produced **decisions, code changes, or
discoveries worth revisiting**. Skip trivial or purely informational chats —
a debrief with nothing in it is noise in `MEMORY/` forever.

## Procedure

### 1. Write the file
Save to `MEMORY/session-final/YYYYMMDD_HHMMSS.md` (create the slug if it
doesn't exist yet). Use the standard MEMORY format; `**Discovered:**` is the
mandatory date field, so a debrief uses it like any other finding:

```markdown
# Session close — YYYY-MM-DD
> summary: <one-line synthesis of the biggest risk or takeaway>

**Discovered:** YYYY-MM-DD
**Context:** <what the session was about, one line>

## Q1 — What are you least confident about right now?
...

## Q2 — What's the biggest thing the user is missing about this situation? What don't they realize?
...

## Q3 — What insight from today did the user NOT ask to be stored, but should have been?
...

## Q4 — If this breaks in 3 months, what is the most likely reason?
(to find future fragility)
...

## Q5 — If you could add one unrequested, industry-leading feature, what would it be?
(for creative brainstorming)
...

## Q6 — What could the user have done differently to make this session more efficient?
(to improve their prompting)
...

## Q7 — Which skill was missing, wrong or stale?
(a proposal only; "none" is a valid answer)
...
```

### 2. Review today's search misses
Run `<root>/scripts/usage-report.sh --today`.
- **Zero-hit searches:** if this session found the answer, write that finding now.
- **Body-only hits:** the finding exists but its summary lacked the words you
  searched; add them as a `> keywords:` line under its summary
  (`memory-find.sh` prints the line ready to paste).

### 3. Handoff (only when work is unfinished)
If the session stops with work in progress, write
`MEMORY/handoff/YYYYMMDD_HHMMSS_<topic>.md` in the standard MEMORY format (first
time: create the folder and run
`scripts/set-slug.sh handoff "Unfinished work handed to the next session"`).
Summary = what is unfinished, one line. Body, 40 lines at most: state now, the
next step (exact command or file), decisions already taken, what not to redo.
Write it while the session is still warm: it replaces resuming a cold chat,
which re-reads the whole conversation. `scripts/bootstrap.sh` lists every
handoff whose summary does not start with `[STALE`; when the work is finished,
prefix the summary `[STALE — done]`.

### 4. Rebuild
Run `<root>/scripts/rebuild-index.sh`, then `<root>/scripts/validate.sh`.

## Rules

- **Q7 is a proposal, never an edit.** Name the skill (or the missing one), what
  was wrong or absent, and the exact change; write "none" if every skill used did
  its job. Never touch a live skill in the debrief: the user approves first, then
  you edit it and re-check its `description:`.

- **No `**Used in:**` line at creation.** Per `MEMORY/SKILL.md`, `Used in`
  starts absent and is added the first time the finding actually answers a
  task. Pre-filling it claims a domain the file never earned and pollutes the
  auto-promotion signal (which counts distinct domains at ≥3).
- **The `> summary:` line is the whole point.** It's what a future session
  reads in `MEMORY/INDEX.md` to decide whether to open the file. "Session
  close" tells nobody anything — lead with the biggest risk or takeaway, so
  it can be matched against a future task.
- **Answer honestly, not diplomatically.** Q1 and Q6 are worthless if softened;
  the reader is a future agent (or the user) trying to avoid a repeat, not an
  audience to reassure.
- Debriefs are findings like any other: never delete one, supersede it.

## Gotchas
- Don't let the debrief substitute for writing findings *during* the session.
  A gotcha discovered at 10:00 belongs in its own MEMORY file at 10:00 — the
  debrief is reflection, not a dumping ground for the day's discoveries.
