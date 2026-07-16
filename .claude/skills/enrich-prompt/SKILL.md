---
name: enrich-prompt
description: Improve a raw prompt using the .agentic_context knowledge base — rewrites it for clarity, injects matching KNOWLEDGE/MEMORY/SKILLS content, shows the enriched prompt, and asks before executing. Use when the user says "enrich/improve this prompt" or wants project context attached to a task before running it.
argument-hint: <the raw prompt to improve>
---
# /enrich-prompt — thin wrapper

The canonical procedure lives in the framework itself:
**read `.agentic_context/SKILLS/meta/improve-prompt/SKILL.md` and follow it
exactly** with the raw prompt below. Do not improvise a different flow here —
this file intentionally holds no logic, so the framework copy stays the single
source of truth and travels to other projects unchanged.

Raw prompt to improve:

$ARGUMENTS

If `$ARGUMENTS` is empty, ask the user for the prompt they want enriched —
don't guess one from conversation history.

Remember the contract: **show the enriched prompt first and wait for the
user's explicit choice (run here / copy-only / adjust) before executing.**
