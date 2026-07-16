#!/usr/bin/env bash
# Remote installer for the .agentic_context framework (AgenticMemory).
#
#   curl -fsSL https://raw.githubusercontent.com/ricardopsantos/AgenticMemory/main/install-claude-science.sh | bash
#
# Installs into the CURRENT directory by default. Options (after `bash -s --`):
#
#   curl -fsSL <url> | bash -s -- [target-project-dir] [--force]
#
# What it does:
#   1. Downloads the AgenticMemory repo tarball (no git required — curl + tar only).
#   2. Copies the framework skeleton: rules (AGENTS.md/CLAUDE.md), MAIN_PROMPT.md,
#      the three folder SKILL.md entry points, the scripts, and SKILLS/meta/
#      (improve-prompt, reconcile-summaries). Project-specific skills are NOT shipped.
#   3. Seeds KNOWLEDGE/ and MEMORY/ with dummy examples (marked "delete me").
#   4. Points the Root: path in the installed MAIN_PROMPT.md at the install location.
#   5. Installs the /enrich-prompt wrapper into <target>/.claude/skills/ (if shipped).
#   6. Builds the indexes and validates the install.
#
# Refuses to touch an existing .agentic_context/ unless --force is given.
# Pin a branch/tag with: AGENTIC_MEMORY_REF=<ref> curl ... | bash
set -euo pipefail

REPO_OWNER="ricardopsantos"
REPO_NAME="AgenticMemory"
REF="${AGENTIC_MEMORY_REF:-main}"
TARBALL_URL="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/refs/heads/${REF}"

# --- args (never interactive: stdin belongs to `curl | bash`) ---
TARGET_ARG="."
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force)     FORCE=1 ;;
    -h|--help)   sed -n '2,20p' "$0" 2>/dev/null || true; exit 0 ;;
    *)           TARGET_ARG="$arg" ;;
  esac
done
[ -d "$TARGET_ARG" ] || { echo "ERROR: target project folder does not exist: $TARGET_ARG"; exit 1; }
TARGET="$(cd "$TARGET_ARG" && pwd)"
DEST="$TARGET/.agentic_context"

if [ -e "$DEST" ]; then
  if [ "$FORCE" -eq 1 ]; then
    echo "• --force: removing existing $DEST"
    rm -rf "$DEST"
  else
    echo "ERROR: $DEST already exists. Re-run with --force to overwrite it:"
    echo "  curl -fsSL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REF}/install-claude-science.sh | bash -s -- ${TARGET_ARG} --force"
    exit 1
  fi
fi

# --- fetch the repo tarball to a temp dir ---
command -v curl >/dev/null || { echo "ERROR: curl is required"; exit 1; }
command -v tar  >/dev/null || { echo "ERROR: tar is required";  exit 1; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "• Downloading ${REPO_OWNER}/${REPO_NAME}@${REF}"
curl -fsSL "$TARBALL_URL" | tar -xz -C "$TMP"
SRC="$TMP/${REPO_NAME}-${REF}/.agentic_context"
[ -d "$SRC" ] || { echo "ERROR: .agentic_context/ not found in the downloaded repo (ref: ${REF})"; exit 1; }

echo "• Installing framework → $DEST"
mkdir -p "$DEST/scripts" "$DEST/KNOWLEDGE/project" "$DEST/KNOWLEDGE/docs" \
         "$DEST/MEMORY/example-topic" "$DEST/SKILLS"

# --- framework skeleton (copied as-is) ---
for f in AGENTS.md CLAUDE.md MAIN_PROMPT.md README.md; do
  cp "$SRC/$f" "$DEST/$f"
done
for s in rebuild-index.sh validate.sh confirm-summary.sh; do
  cp "$SRC/scripts/$s" "$DEST/scripts/$s"
done
chmod +x "$DEST/scripts/"*.sh
cp "$SRC/KNOWLEDGE/SKILL.md" "$DEST/KNOWLEDGE/SKILL.md"
cp "$SRC/MEMORY/SKILL.md"    "$DEST/MEMORY/SKILL.md"

# --- SKILLS: entry point + meta/ only (project-specific skills stay out) ---
cp "$SRC/SKILLS/SKILL.md" "$DEST/SKILLS/SKILL.md"
cp -R "$SRC/SKILLS/meta" "$DEST/SKILLS/meta"
find "$DEST" -name '.DS_Store' -delete 2>/dev/null || true
SKILL_COUNT=$(find "$DEST/SKILLS" -mindepth 2 -name SKILL.md | wc -l | tr -d ' ')

# --- point the pasted prompt at the real install location ---
sed -i.bak "s|^Root: \`[^\`]*\`|Root: \`$DEST\`|" "$DEST/MAIN_PROMPT.md" && rm -f "$DEST/MAIN_PROMPT.md.bak"

# --- /enrich-prompt wrapper for Claude Code (optional; skip if user has one) ---
WRAPPER_SRC="$TMP/${REPO_NAME}-${REF}/.claude/skills/enrich-prompt/SKILL.md"
WRAPPER_NOTE="not shipped in this ref"
if [ -e "$WRAPPER_SRC" ]; then
  if [ -e "$TARGET/.claude/skills/enrich-prompt/SKILL.md" ] && [ "$FORCE" -ne 1 ]; then
    WRAPPER_NOTE="kept existing $TARGET/.claude/skills/enrich-prompt/"
  else
    mkdir -p "$TARGET/.claude/skills/enrich-prompt"
    cp "$WRAPPER_SRC" "$TARGET/.claude/skills/enrich-prompt/SKILL.md"
    WRAPPER_NOTE="installed → $TARGET/.claude/skills/enrich-prompt/"
  fi
fi

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
**Context:** created by the installer

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
**Context:** created by the installer
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
echo "  Skills installed:    $SKILL_COUNT (meta only — add your own under SKILLS/<category>/)"
echo "  /enrich-prompt:      $WRAPPER_NOTE"
echo "  Dummy KNOWLEDGE:     2 (marked 'delete me' — replace with real docs)"
echo "  Dummy MEMORY:        2 (marked 'delete me' — replace with real findings)"
echo
echo "Next steps:"
echo "  1. Open $DEST/MAIN_PROMPT.md — the Root: path is already set."
echo "  2. Paste its contents at the start of each agent session."
echo "  3. Replace the dummy docs/findings, then run scripts/rebuild-index.sh."
