---
name: knowledge
description: Entry point for the KNOWLEDGE folder — static, authoritative reference docs organized into domain families. Use when you need project context, architecture, product structure, or any stable reference.
---
# Knowledge
## Purpose
Static ground-truth reference. Load only what a task needs; never bulk-load.
## Discovery
- Live list is **`KNOWLEDGE/INDEX.md`** (load it at start; it's small).
- Each INDEX entry = the doc's own `> summary:` line. **Doc = source of truth, INDEX = derived.**
- `[CORE]` docs are loaded at start by the main prompt; the rest are lazy.
## Adding/changing a doc
1. Drop `.md` into the right family (TitleCase name). New family only when ≥2 docs share a domain. Nesting is allowed — e.g. `project/wallet/WalletSDKArchitecture.md`; the index script recurses.
2. Line 1 `# Title`; **line 2 `> summary: <one line>`** (prefix `[CORE]` if always-load); optional **line 3 `> keywords: <term>, <term>`** for words a search would use that the summary lacks. Keywords never enter the loaded index; `scripts/memory-find.sh --knowledge <words>` finds them. The summary is a routing line, at most 200 characters (`validate.sh` warns): what the doc is and when to read it. This index is read in every session, so detail belongs in the body.
   Optional `**Verify-by:** YYYY-MM-DD` on a doc holding volatile facts (ports, hosts, URLs): `validate.sh` warns once the date has passed.
3. Run `./scripts/rebuild-index.sh`.

Changed a doc's body? Re-check its `> summary:` line still fits, then rebuild. The system tracks this: a body-only change makes `validate.sh` warn `UNCONFIRMED` until you either edit the summary or run `./scripts/confirm-summary.sh <file>` (procedure: `SKILLS/meta/reconcile-summaries`).
## Rules
Ground truth unless evidently stale → note staleness in MEMORY, don't edit mid-task. If INDEX ≠ `tree`, rebuild; disk wins.
