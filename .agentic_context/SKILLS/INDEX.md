# SKILLS — Index

> DERIVED from each skill's frontmatter `description:`. Rebuilt: 2026-07-16. Run `./scripts/rebuild-index.sh`.
> `(~N tok)` = estimated context cost to open that skill (size ÷ 4).

**Know they exist via this list. Load a skill's SKILL.md only when its description matches the task.**

## meta/
- `meta/improve-prompt/` — Turn a raw user prompt into an enriched, context-loaded prompt using .agentic_context — rewrite for clarity, match it against the three INDEX.md files, inject the relevant KNOWLEDGE/MEMORY/SKILLS, show the result, and execute only on user confirmation. Load when asked to improve/enrich/prepare a prompt before running it. (~849 tok)
- `meta/reconcile-summaries/` — Resolve UNCONFIRMED-summary warnings from validate.sh — for each doc whose body changed since its summary was last confirmed, re-read the body and either rewrite the summary or confirm it via scripts/confirm-summary.sh, then rebuild. Load when validate reports UNCONFIRMED summaries, or for a periodic summary-hygiene pass. (~612 tok)
- `meta/session-debrief/` — End-of-session retrospective — answer six fixed questions and save them as a MEMORY finding under session-final/. Load at the end of any session that produced decisions, code changes, or discoveries worth revisiting; skip for trivial or purely informational chats. (~754 tok)
