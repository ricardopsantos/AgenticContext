#!/usr/bin/env bash
# Remote installer for the .agentic_context framework (AgenticContext).
#
#   curl -fsSL https://raw.githubusercontent.com/ricardopsantos/AgenticContext/main/Auxiliar/install.sh | bash
#
# Installs into the CURRENT directory by default. Options (after `bash -s --`):
#
#   curl -fsSL <url> | bash -s -- [target-project-dir] [options]
#
# Options:
#   --dir <name>   context folder name (default: .agentic_context)
#   --visible      drop the leading dot, so the folder is not hidden
#   --force        overwrite an existing install
#   --yes          never prompt; take the defaults
#
# With no --dir/--visible/--yes and a terminal available, it asks for the
# folder name and whether to hide it. `curl | bash` gives the script its own
# stdin, so the question is read from /dev/tty; with no tty it silently keeps
# the defaults.
#
# What it does:
#   0. Picks the context folder name (default .agentic_context; see Options).
#   1. Downloads the AgenticContext repo tarball (no git required — curl + tar only).
#   2. Copies the framework skeleton: rules (AGENTS.md/CLAUDE.md), MAIN_PROMPT.md,
#      the three folder SKILL.md entry points, the scripts, and SKILLS/meta/
#      (improve-prompt, reconcile-summaries, session-debrief). Project-specific
#      skills are NOT shipped.
#   3. Seeds KNOWLEDGE/ and MEMORY/ with dummy examples (marked "delete me").
#   4. Installs the /enrich-prompt wrapper into <target>/.claude/skills/ (if shipped).
#   5. Builds the indexes and validates the install.
#
# The installed MAIN_PROMPT.md needs no patching whatever the folder is named:
# it discovers its root by walking up from the working directory and matching on
# folder *contents* (scripts/rebuild-index.sh + KNOWLEDGE/), never on the name.
#
# Refuses to touch an existing .agentic_context/ unless --force is given.
# Pin a branch/tag with: AGENTIC_CONTEXT_REF=<ref> curl ... | bash
set -euo pipefail

REPO_OWNER="ricardopsantos"
REPO_NAME="AgenticContext"
REF="${AGENTIC_CONTEXT_REF:-main}"
TARBALL_URL="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/refs/heads/${REF}"

# --- args ---
# stdin belongs to `curl | bash`, so anything interactive must read /dev/tty.
DEFAULT_NAME=".agentic_context"
TARGET_ARG="."
FORCE=0
ASSUME_YES=0
CTX_NAME=""
VISIBLE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --force)     FORCE=1; shift ;;
    --yes|-y)    ASSUME_YES=1; shift ;;
    --visible)   VISIBLE=1; shift ;;
    --dir)       CTX_NAME="${2:-}"; [ -n "$CTX_NAME" ] || { echo "ERROR: --dir needs a name"; exit 1; }; shift 2 ;;
    --dir=*)     CTX_NAME="${1#*=}"; shift ;;
    -h|--help)   sed -n '2,30p' "$0" 2>/dev/null || true; exit 0 ;;
    *)           TARGET_ARG="$1"; shift ;;
  esac
done
[ -d "$TARGET_ARG" ] || { echo "ERROR: target project folder does not exist: $TARGET_ARG"; exit 1; }
TARGET="$(cd "$TARGET_ARG" && pwd)"

# --- choose the context folder name ---
# Rules, in order: --dir wins and is used verbatim; otherwise ask on a real
# terminal; otherwise take the default. --visible always strips a leading dot.
# No name is ever silently rewritten — what you pass is what you get.
if [ -n "$CTX_NAME" ]; then
  :                                     # explicit --dir: use verbatim
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
    echo "ERROR: $DEST already exists. Re-run with --force to overwrite it:"
    echo "  curl -fsSL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REF}/Auxiliar/install.sh | bash -s -- ${TARGET_ARG} --force"
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
REPO_ROOT="$TMP/${REPO_NAME}-${REF}"
SRC="$REPO_ROOT/.agentic_context"
[ -d "$SRC" ] || { echo "ERROR: .agentic_context/ not found in the downloaded repo (ref: ${REF})"; exit 1; }

echo "• Installing framework → $DEST"
mkdir -p "$DEST/scripts" "$DEST/KNOWLEDGE/project" "$DEST/KNOWLEDGE/docs" \
         "$DEST/MEMORY/example-topic" "$DEST/SKILLS"

# --- framework skeleton (copied as-is) ---
# AGENTS.md/CLAUDE.md live inside .agentic_context/; MAIN_PROMPT.md and
# README.md live at the repo root. Both end up inside the installed folder.
for f in AGENTS.md CLAUDE.md; do
  cp "$SRC/$f" "$DEST/$f"
done
cp "$REPO_ROOT/MAIN_PROMPT.md" "$DEST/MAIN_PROMPT.md"
cp "$REPO_ROOT/README.md"      "$DEST/README.md"
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

# The prompt self-discovers its root — nothing to patch.

# --- /enrich-prompt wrapper for Claude Code (optional; skip if user has one) ---
WRAPPER_SRC="$REPO_ROOT/.claude/skills/enrich-prompt/SKILL.md"
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

HIDDEN_NOTE="hidden"; [ "${CTX_NAME#.}" = "$CTX_NAME" ] && HIDDEN_NOTE="visible"
echo
echo "DONE — installed at $DEST"
echo "  Context folder:      $CTX_NAME/ ($HIDDEN_NOTE)"
[ "$CTX_NAME" = "$DEFAULT_NAME" ] && \
  echo "                       default — override with: --dir <name> [--visible]"
echo "  Skills installed:    $SKILL_COUNT (meta only — add your own under SKILLS/<category>/)"
echo "  /enrich-prompt:      $WRAPPER_NOTE"
echo "  Dummy KNOWLEDGE:     2 (marked 'delete me' — replace with real docs)"
echo "  Dummy MEMORY:        2 (marked 'delete me' — replace with real findings)"
echo
echo "Next steps:"
echo "  1. Paste $DEST/MAIN_PROMPT.md at the start of each agent session."
echo "     (It finds its own root by content, so the folder name is free."
echo "      Rename $CTX_NAME/ whenever you like — nothing to re-edit.)"
echo "  2. Replace the dummy docs/findings, then run scripts/rebuild-index.sh."
