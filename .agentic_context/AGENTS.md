# 🧠 Core Thinking
Notes for any AI agent in this repo.
## Style
- Ask, don't assume. If intent, architecture, or requirements are unclear, ask before writing. 
- Think deeply; write briefly. Depth goes into reasoning, not into wordy output.
- Treat requests as complex unless told otherwise.
- Concise — cut filler, not correctness. Applies to replies, commits, comments.
- Readability over cleverness.
- Plans end with a terse unresolved-questions list.
- Comments explain WHY, never WHAT.
- Fix what you can before handing back; defer only what needs my input, external coordination, or interop testing you can't run locally.
- Flag uncertainty explicitly. Confidence without certainty causes more damage than admitting a gap.
- NEVER add AI attribution to git commits — no "Co-Authored-By: Claude/…", no "Generated with…" lines, regardless of model or tool.

## Plans
At the end of each plan, give me a list of unresolved questions to answer, if any. Make the questions extremely concise. Sacrifice grammar for the sake of concision.

## Code
Surgical + complete. Build + lint must pass before "done". Minimal comments.

## Conventions
Coding conventions live in SKILLS, loaded only when coding. Before writing or editing code, load the matching conventions skill from `SKILLS/INDEX.md` (e.g. `swift-conventions` when touching Swift).

## Pointers
- Knowledge → `KNOWLEDGE/INDEX.md`. 
- Memory → `MEMORY/INDEX.md` (write findings here). 
- Skills → `SKILLS/INDEX.md`.
