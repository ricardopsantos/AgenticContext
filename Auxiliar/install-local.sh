#!/usr/bin/env bash
# Installs the .agentic_context framework into a target project, from a local clone.
#
#   ./Auxiliar/install-local.sh <target-project-dir> [options]
#
# Options:
#   --dir <name>   context folder name (default: .agentic_context)
#   --visible      drop the leading dot, so the folder is not hidden
#   --force        overwrite an existing install
#   --yes          never prompt; take the defaults
#
# Copies the framework skeleton (rules, prompt, scripts, folder SKILL.md files)
# and the ENTIRE SKILLS/ tree from this repo. KNOWLEDGE/ and MEMORY/ start with
# generated dummy examples (marked "delete me") instead of this repo's content.
# Refuses to touch an existing install unless --force is given.
#
# The installed MAIN_PROMPT.md needs no patching whatever the folder is named:
# it discovers its root by walking up from the working directory and matching on
# folder *contents* (scripts/rebuild-index.sh + KNOWLEDGE/), never on the name.
set -euo pipefail

# This script lives in Auxiliar/; the framework source is at the repo root.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO/.agentic_context"
[ -d "$SRC" ] || { echo "ERROR: source folder not found: $SRC"; exit 1; }

# --- args ---
DEFAULT_NAME=".agentic_context"
TARGET_ARG=""; FORCE=0; ASSUME_YES=0; CTX_NAME=""; VISIBLE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --force)     FORCE=1; shift ;;
    --yes|-y)    ASSUME_YES=1; shift ;;
    --visible)   VISIBLE=1; shift ;;
    --dir)       CTX_NAME="${2:-}"; [ -n "$CTX_NAME" ] || { echo "ERROR: --dir needs a name"; exit 1; }; shift 2 ;;
    --dir=*)     CTX_NAME="${1#*=}"; shift ;;
    -h|--help)   TARGET_ARG=""; break ;;
    *)           TARGET_ARG="$1"; shift ;;
  esac
done
if [ -z "$TARGET_ARG" ]; then
  echo "usage: ./Auxiliar/install-local.sh <target-project-dir> [options]"
  echo "  --dir <name>   context folder name (default: $DEFAULT_NAME)"
  echo "  --visible      drop the leading dot, so the folder is not hidden"
  echo "  --force        overwrite an existing install at the target"
  echo "  --yes          never prompt; take the defaults"
  exit 1
fi
[ -d "$TARGET_ARG" ] || { echo "ERROR: target project folder does not exist: $TARGET_ARG"; exit 1; }
TARGET="$(cd "$TARGET_ARG" && pwd)"

# --- choose the context folder name ---
# --dir wins and is used verbatim; otherwise ask on a real terminal; otherwise
# take the default. --visible always strips a leading dot. No silent rewrites.
if [ -n "$CTX_NAME" ]; then
  :
elif [ "$ASSUME_YES" -eq 0 ] && [ "$VISIBLE" -eq 0 ] && [ -r /dev/tty ] && [ -t 1 ]; then
  printf 'Context folder name [%s]: ' "$DEFAULT_NAME" > /dev/tty
  IFS= read -r ANS < /dev/tty || ANS=""
  CTX_NAME="${ANS:-$DEFAULT_NAME}"
  printf 'Hidden (leading dot)? [Y/n]: ' > /dev/tty
  IFS= read -r ANS_HIDE < /dev/tty || ANS_HIDE=""
  BASE="${CTX_NAME#.}"
  case "$ANS_HIDE" in [Nn]*) CTX_NAME="$BASE" ;; *) CTX_NAME=".$BASE" ;; esac
else
  CTX_NAME="$DEFAULT_NAME"
fi
[ "$VISIBLE" -eq 1 ] && CTX_NAME="${CTX_NAME#.}"

case "$CTX_NAME" in
  */*|""|.|..) echo "ERROR: invalid context folder name: '$CTX_NAME' (no slashes)"; exit 1 ;;
esac

DEST="$TARGET/$CTX_NAME"

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

# --- framework skeleton ---
# AGENTS.md/CLAUDE.md live inside .agentic_context/; MAIN_PROMPT.md and
# README.md live at the repo root. Both end up inside the installed folder.
for f in AGENTS.md CLAUDE.md; do
  cp "$SRC/$f" "$DEST/$f"
done
cp "$REPO/MAIN_PROMPT.md" "$DEST/MAIN_PROMPT.md"
cp "$REPO/README.md"      "$DEST/README.md"

for s in rebuild-index.sh validate.sh confirm-summary.sh; do
  cp "$SRC/scripts/$s" "$DEST/scripts/$s"
done
chmod +x "$DEST/scripts/"*.sh
cp "$SRC/KNOWLEDGE/SKILL.md" "$DEST/KNOWLEDGE/SKILL.md"
cp "$SRC/MEMORY/SKILL.md"    "$DEST/MEMORY/SKILL.md"

# --- SKILLS: always copied in full (categories + every skill) ---
cp -R "$SRC/SKILLS" "$DEST/SKILLS"
rm -f "$DEST/SKILLS/INDEX.md"                       # regenerated below
find "$DEST" -name '.DS_Store' -delete 2>/dev/null || true
SKILL_COUNT=$(find "$DEST/SKILLS" -mindepth 2 -name SKILL.md | wc -l | tr -d ' ')

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
**Context:** created by install-local.sh

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
**Context:** created by install-local.sh
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

HIDDEN_NOTE="hidden"; [ "${CTX_NAME#.}" = "$CTX_NAME" ] && HIDDEN_NOTE="visible"
echo
echo "DONE — installed at $DEST"
echo "  Context folder:      $CTX_NAME/ ($HIDDEN_NOTE)"
[ "$CTX_NAME" = "$DEFAULT_NAME" ] && \
  echo "                       default — override with: --dir <name> [--visible]"
echo "  Skills copied:       $SKILL_COUNT"
echo "  Dummy KNOWLEDGE:     2 (marked 'delete me' — replace with real docs)"
echo "  Dummy MEMORY:        2 (marked 'delete me' — replace with real findings)"
echo
echo "Next steps:"
echo "  1. Paste $DEST/MAIN_PROMPT.md at the start of each agent session."
echo "     (It finds its own root by content, so the folder name is free."
echo "      Rename $CTX_NAME/ whenever you like — nothing to re-edit.)"
echo "  2. Replace the dummy docs/findings, then run scripts/rebuild-index.sh."
