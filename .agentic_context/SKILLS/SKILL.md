---
name: skills-root
description: Entry point for available skills, organized by domain. Generic router — load a skill only when needed.
---
# Skills Root
## Purpose
How-to guides (vs KNOWLEDGE=reference, MEMORY=findings). Categories are domain subfolders; each skill is its own folder with a SKILL.md.
## Discovery
- Live list is **`SKILLS/INDEX.md`** (entries = each skill's frontmatter `description:`). This is the "know they exist" layer.
- Load a skill's own SKILL.md **only when its description matches the task, or the user says so** — never bulk-load.
## Adding a skill
1. `SKILLS/<category>/<skill-name>/SKILL.md` with frontmatter `name:` + `description:` (the description is what the index shows — make it trigger-worthy, at most 300 characters; `validate.sh` warns).
2. Run `./scripts/rebuild-index.sh`.

Changed a skill? Re-check its `description:` still fits, then rebuild — the index copies the description verbatim, so a stale one shows up verbatim.
