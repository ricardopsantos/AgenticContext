---
name: improve-prompt
description: Turn a raw user prompt into an enriched, context-loaded prompt using .agentic_context — rewrite for clarity, match it against the three INDEX.md files, inject the relevant KNOWLEDGE/MEMORY/SKILLS, show the result, and execute only on user confirmation. Load when asked to improve/enrich/prepare a prompt before running it.
---
# Improve Prompt

Given a raw prompt, produce an **enriched prompt** = the same intent, rewritten
for clarity, with the relevant `.agentic_context` content attached. Always
**show the result and wait for confirmation** before executing — never run the
enriched prompt silently.

## Procedure

### 1. Fresh map first
Run `<root>/scripts/rebuild-index.sh`, then `<root>/scripts/validate.sh`.
Skip only if both already ran this session and no files changed since.

### 2. Read the indexes (not the docs)
Read `KNOWLEDGE/INDEX.md`, `MEMORY/INDEX.md`, `SKILLS/INDEX.md`. Match each
entry's one-line summary/description **semantically** against the prompt — the
summary is the trigger; don't open a file whose summary doesn't relate.

Selection rules:
- `[CORE]` KNOWLEDGE always qualifies (it's meant to be in context anyway).
- Skip anything `[STALE]`; note `[PROMOTE?]` entries to surface to the user.
- Tiered skills (light/regular/deep): pick **one** tier — light by default,
  higher only if the prompt is explicitly about that domain's internals.
- Respect the `(~N tok)` costs. Budget ≈ **4k tokens** of injected content.
  Small docs (≲1k tok) inline; larger matches become *load instructions*
  ("load `SKILLS/...` before starting"), not pasted bodies.

### 3. Rewrite the prompt
Keep the user's intent; improve the wording:
- Expand project acronyms/jargon using whatever glossary-type KNOWLEDGE doc
  the index shows (open it only if the prompt actually contains such terms).
- Make the ask concrete: name the target repo/module/file when a KNOWLEDGE
  doc (a repo map, product map, or similar) resolves it.
- Add explicit acceptance criteria and constraints implied but unstated.
- Flag genuine ambiguity as an open question for the user — don't invent
  requirements to fill gaps.

### 4. Assemble the enriched prompt
```markdown
## Task
<rewritten prompt>

## Acceptance criteria
- <criterion>

## Context (from .agentic_context)
### <path> — why it matched
<inlined content, or "Load this file before starting.">

## Open questions
- <only if any>
```

### 5. Show, then confirm
Present the enriched prompt to the user with a one-line note of what was
matched and what was deliberately left out (and any `[PROMOTE?]` flags seen).
Ask: **run it here, copy-only, or adjust?** Execute only on explicit "run".

### 6. After execution (if run)
Follow the normal per-task rules: update `**Used in:**` on any MEMORY finding
that answered, write qualifying new findings, rebuild the indexes.

## Gotchas
- The enriched prompt must stay self-contained: someone pasting it into a
  fresh session (or another LLM) should need nothing else — that's why matched
  content is inlined, and only oversized items degrade to load instructions.
- Don't bulk-load "just in case": an enriched prompt drowning in irrelevant
  context is worse than the raw prompt. When unsure a doc matches, leave it
  out and mention it under Open questions instead.
- Never edit any INDEX.md by hand while doing this — indexes stay derived.
