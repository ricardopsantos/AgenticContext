# Changelog

System files only (scripts, SKILL.md skeletons, REQUIREMENTS.md, bootstrap prompt). Written by `scripts/bump-version.sh`.

## 1.3.0 — 2026-11-27
- '> keywords:' line under any summary (KNOWLEDGE and MEMORY), searched via INDEX.full.md, never loaded; memory-find.sh --knowledge; body hits print a ready keywords line; validate warns over 150 chars (R35)

## 1.2.0 — 2026-11-22
- No framework change (a local install added its own POLICIES/ file; the framework still ships no POLICIES content, R34)

## 1.1.0 — 2026-11-18
- POLICIES/ folder: extra rule files the user keeps beside AGENTS.md; bootstrap lists and the prompt reads every POLICIES/*.md; validate accepts the folder and flags non-.md files; stats counts them (R34)

## 1.0.3 — 2026-11-16
- rebuild-index.sh and validate.sh name a missing scripts/lib.sh and the fix (R33)

## 1.0.2 — 2026-11-16
- bump-version.sh --restamp: refresh the prompt title and manifest for a copy of the system without bumping (R21)

## 1.0.1 — 2026-11-16
- Manifest names the prompt MAIN_PROMPT.md wherever it sits (inside the root or beside it); needed for installs

## 1.0.0 — 2026-11-16
- First versioned release: VERSION + CHANGELOG + manifest; bootstrap.sh; one-pass rebuild/validate (80 s -> 3 s); memory-find body fallback, [ARCHIVE] slugs, Keywords; summary caps; Verify-by; mark-used.sh; handoffs

