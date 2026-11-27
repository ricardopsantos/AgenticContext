# SKILLS — Index

> DERIVED from each skill's frontmatter `description:`. Rebuilt: 2026-11-27. Run `./scripts/rebuild-index.sh`. System v1.3.0.
> `(~N tok)` = estimated context cost to open that skill (size ÷ 4).

**Know they exist via this list. Load a skill's SKILL.md only when its description matches the task.**

## meta/
- `meta/reconcile-summaries/` — Resolve UNCONFIRMED-summary warnings from validate.sh: re-read each doc whose body changed, then rewrite its summary or confirm it via scripts/confirm-summary.sh, and rebuild. Load when validate reports UNCONFIRMED summaries, or for a periodic summary-hygiene pass. (~622 tok)
- `meta/session-debrief/` — End-of-session retrospective — answer seven fixed questions and save them as a MEMORY finding under session-final/. Load at the end of any session that produced decisions, code changes, or discoveries worth revisiting; skip for trivial or purely informational chats. (~1.1k tok)
