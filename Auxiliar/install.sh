#!/usr/bin/env bash
# Installs the .agentic_context framework into a target project.
#
#   ./install.sh <target-project-dir> [--force]
#
# Copies the framework skeleton (rules, prompt, scripts, folder SKILL.md files)
# and the ENTIRE SKILLS/ tree from this repo. KNOWLEDGE/ and MEMORY/ start with
# generated dummy examples (marked "delete me") instead of this repo's content.
# The Root: path in the installed MAIN_PROMPT.md is set to the target location.
# Refuses to touch an existing install unless --force is given.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/.agentic_context"
[ -d "$SRC" ] || { echo "ERROR: source folder not found: $SRC"; exit 1; }

# --- args ---
TARGET_ARG="${1:-}"; FORCE=0
[ "${2:-}" = "--force" ] && FORCE=1
if [ -z "$TARGET_ARG" ] || [ "$TARGET_ARG" = "-h" ] || [ "$TARGET_ARG" = "--help" ]; then
  echo "usage: ./install.sh <target-project-dir> [--force]"
  echo "  Installs .agentic_context/ into the given project folder."
  echo "  --force  overwrite an existing .agentic_context/ at the target."
  exit 1
fi
[ -d "$TARGET_ARG" ] || { echo "ERROR: target project folder does not exist: $TARGET_ARG"; exit 1; }
TARGET="$(cd "$TARGET_ARG" && pwd)"
DEST="$TARGET/.agentic_context"

if [ -e "$DEST" ]; then
  if [ "$FORCE" -eq 1 ]; then
    echo "• --force: removing existing $DEST"
    rm -rf "$DEST"
  else
    echo "ERROR: $DEST already exists. Re-run with --force to overwrite it."
    exit 1
  fi
fi

echo "• Installing framework → $DEST"
mkdir -p "$DEST/scripts" "$DEST/KNOWLEDGE/project" "$DEST/KNOWLEDGE/docs" "$DEST/MEMORY/example-topic"

# --- framework skeleton (always copied as-is) ---
for f in AGENTS.md CLAUDE.md MAIN_PROMPT.md README.md; do
  cp "$SRC/$f" "$DEST/$f"
done
cp "$SRC/scripts/rebuild-index.sh" "$SRC/scripts/validate.sh" "$DEST/scripts/"
chmod +x "$DEST/scripts/"*.sh
cp "$SRC/KNOWLEDGE/SKILL.md" "$DEST/KNOWLEDGE/SKILL.md"
cp "$SRC/MEMORY/SKILL.md"    "$DEST/MEMORY/SKILL.md"

# --- SKILLS: always copied in full (categories + every skill) ---
cp -R "$SRC/SKILLS" "$DEST/SKILLS"
rm -f "$DEST/SKILLS/INDEX.md"                       # regenerated below
find "$DEST" -name '.DS_Store' -delete 2>/dev/null || true
SKILL_COUNT=$(find "$DEST/SKILLS" -mindepth 2 -name SKILL.md | wc -l | tr -d ' ')

# --- point the pasted prompt at the real install location ---
sed -i.bak "s|^Root: \`[^\`]*\`|Root: \`$DEST\`|" "$DEST/MAIN_PROMPT.md" && rm -f "$DEST/MAIN_PROMPT.md.bak"

# --- dummy KNOWLEDGE docs (delete once real content exists) ---
TODAY=$(date +%Y-%m-%d)
cat > "$DEST/KNOWLEDGE/project/ProjectMap.md" <<EOF
# Project Map (dummy)
> summary: [CORE] (dummy — replace me) One-line map of the project: repos, modules, and where things live.

Replace this file with your real always-loaded project map. Keep the \`[CORE]\`
prefix only for docs relevant to almost every task — that set must stay tiny.
Format rules: line 1 is the title, line 2 is the one-line \`> summary:\`, line 3
is blank. Run \`./scripts/rebuild-index.sh\` after any change.
EOF

cat > "$DEST/KNOWLEDGE/docs/ExampleReference.md" <<EOF
# Example Reference (dummy)
> summary: (dummy — delete me) Example of a lazily-loaded reference doc, opened only when this summary matches the task.

This doc has no \`[CORE]\` tag, so it costs nothing at session start — the agent
sees only the summary line above (via the index) and opens the doc on match.
Group docs into family folders (like \`docs/\` or \`project/\`); files at the
KNOWLEDGE root are invisible to the index and flagged by validate.sh.
EOF

# --- dummy MEMORY findings (delete once real findings exist) ---
TS=$(date +%Y%m%d_%H%M%S)
cat > "$DEST/MEMORY/example-topic/${TS}_example-finding.md" <<EOF
# Example Finding (dummy)
> summary: (dummy — delete me) Example session finding: non-obvious, will recur, too narrow for KNOWLEDGE.

**Discovered:** $TODAY
**Context:** created by install.sh

## Finding
Write findings the moment you discover them: what surprised you and why it
matters. Timestamped filename, one-line summary on line 2, blank line 3.

## Caveats
Never delete a finding — supersede it (new file, prefix the old summary \`[STALE]\`).
EOF

cat > "$DEST/MEMORY/example-topic/${TS}_example-usage-tracking.md" <<EOF
# Example Usage Tracking (dummy)
> summary: (dummy — delete me) Example finding with a Used-in line — at 3 distinct domains the index auto-flags it [PROMOTE?].

**Discovered:** $TODAY
**Context:** created by install.sh
**Used in:** example-domain

## Finding
When a finding answers a task, append that task's domain to \`**Used in:**\`.
The rebuild script counts distinct domains and auto-tags the index entry
\`[PROMOTE? auto — used in N domains]\` at ≥3 — generality proven by use.
A human still confirms the actual move into KNOWLEDGE.
EOF

# --- build indexes + verify ---
echo "• Building indexes"
"$DEST/scripts/rebuild-index.sh"
echo "• Validating"
"$DEST/scripts/validate.sh"

echo
echo "DONE — installed at $DEST"
echo "  Skills copied:       $SKILL_COUNT"
echo "  Dummy KNOWLEDGE:     2 (marked 'delete me' — replace with real docs)"
echo "  Dummy MEMORY:        2 (marked 'delete me' — replace with real findings)"
echo
echo "Next steps:"
echo "  1. Open $DEST/MAIN_PROMPT.md — the Root: path is already set."
echo "  2. Paste its contents at the start of each agent session."
echo "  3. Replace the dummy docs/findings, then run scripts/rebuild-index.sh."
