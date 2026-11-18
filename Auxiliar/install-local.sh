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
#   --from <path>  migrate content from a previous install at <path> instead of
#                  seeding dummy examples: copies KNOWLEDGE/, MEMORY/, every
#                  SKILLS/ category except meta/ (meta/ is framework, comes
#                  fresh), and scripts/.summary-hashes (preserves any pending
#                  UNCONFIRMED judgment state). <path> is the old context
#                  folder itself, e.g. /old/project/.agentic_context.
#                  If <path> IS the install destination (the common "re-run
#                  the installer here to pick up bugfixes" case), it's backed
#                  up to <path>.bak-<timestamp> and the fresh install replaces
#                  it automatically — no --force or --in-place needed.
#   --in-place     only with --from pointing elsewhere: after migrating,
#                  back up the old install to <path>.bak-<timestamp> and move
#                  the fresh install onto its old location/name, instead of
#                  leaving the fresh install where --dir/--visible put it.
#   --mode <m>     what to install: "prompt" (just the MAIN_PROMPT.md
#                  scaffold, the default), "mcp" (just the agentic_context_mcp
#                  server, venv included), or "both". Without this flag, a
#                  real terminal is asked; --yes or no tty silently keeps
#                  "prompt" (today's only behavior, unchanged).
#
# Copies the framework skeleton (rules, prompt, scripts, folder SKILL.md files)
# and the ENTIRE SKILLS/ tree from this repo. KNOWLEDGE/ and MEMORY/ start with
# generated dummy examples (marked "delete me") instead of this repo's content,
# unless --from migrates real content over them.
# Refuses to touch an existing install unless --force is given.
#
# With --mode mcp/both: also copies mcp_server/ (agentic_context_mcp) to
# <target>/mcp_server, creates its venv, and pip-installs it — see
# mcp_server/README.md / documents/MCP_SERVER_INSTALL.md for wiring it into
# a client (Claude Desktop, Aurora, ...) afterwards.
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
TARGET_ARG=""; FORCE=0; ASSUME_YES=0; CTX_NAME=""; VISIBLE=0; FROM_ARG=""; IN_PLACE=0; MODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --force)     FORCE=1; shift ;;
    --yes|-y)    ASSUME_YES=1; shift ;;
    --visible)   VISIBLE=1; shift ;;
    --dir)       CTX_NAME="${2:-}"; [ -n "$CTX_NAME" ] || { echo "ERROR: --dir needs a name"; exit 1; }; shift 2 ;;
    --dir=*)     CTX_NAME="${1#*=}"; shift ;;
    --from)      FROM_ARG="${2:-}"; [ -n "$FROM_ARG" ] || { echo "ERROR: --from needs a path"; exit 1; }; shift 2 ;;
    --from=*)    FROM_ARG="${1#*=}"; shift ;;
    --in-place)  IN_PLACE=1; shift ;;
    --mode)      MODE="${2:-}"; shift 2 ;;
    --mode=*)    MODE="${1#*=}"; shift ;;
    -h|--help)   TARGET_ARG=""; break ;;
    *)           TARGET_ARG="$1"; shift ;;
  esac
done
case "$MODE" in
  ""|prompt|mcp|both) ;;
  *) echo "ERROR: --mode must be one of: prompt, mcp, both (got '$MODE')"; exit 1 ;;
esac
if [ -z "$TARGET_ARG" ]; then
  echo "usage: ./Auxiliar/install-local.sh <target-project-dir> [options]"
  echo "  --dir <name>   context folder name (default: $DEFAULT_NAME)"
  echo "  --visible      drop the leading dot, so the folder is not hidden"
  echo "  --force        overwrite an existing install at the target"
  echo "  --yes          never prompt; take the defaults"
  echo "  --from <path>  migrate KNOWLEDGE/MEMORY/SKILLS from a previous install"
  echo "  --in-place     with --from elsewhere: relocate the fresh install onto it"
  echo "  --mode <m>     prompt | mcp | both (default: asks, or 'prompt' under --yes/no tty)"
  exit 1
fi
[ -d "$TARGET_ARG" ] || { echo "ERROR: target project folder does not exist: $TARGET_ARG"; exit 1; }
TARGET="$(cd "$TARGET_ARG" && pwd)"

# --- what to install: prompt scaffold, mcp server, or both ---
if [ -z "$MODE" ]; then
  if [ "$ASSUME_YES" -eq 0 ] && [ -r /dev/tty ] && [ -t 1 ]; then
    printf 'Install [1] prompt-only scaffold  [2] MCP server only  [3] both  [1]: ' > /dev/tty
    IFS= read -r ANS_MODE < /dev/tty || ANS_MODE=""
    case "$ANS_MODE" in
      2) MODE="mcp" ;;
      3) MODE="both" ;;
      *) MODE="prompt" ;;
    esac
  else
    MODE="prompt"
  fi
fi
WANT_PROMPT=0; WANT_MCP=0
case "$MODE" in
  prompt) WANT_PROMPT=1 ;;
  mcp)    WANT_MCP=1 ;;
  both)   WANT_PROMPT=1; WANT_MCP=1 ;;
esac

if [ "$WANT_PROMPT" -eq 1 ]; then
# --- choose the context folder name (needed before resolving FROM, so the
# migration prompt can offer "upgrade the install found here" as the default) ---
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

# --- resolve migration source, if any ---
# --from wins verbatim; otherwise ask on a real terminal. If an install
# already exists at DEST, blank defaults to upgrading it in place; otherwise
# blank means skip. No prompt at all under --yes or without a tty.
FROM=""
if [ -n "$FROM_ARG" ]; then
  FROM="$FROM_ARG"
elif [ "$ASSUME_YES" -eq 0 ] && [ -r /dev/tty ] && [ -t 1 ]; then
  if [ -e "$DEST" ]; then
    printf 'Existing install found at %s.\nMigrate KNOWLEDGE/MEMORY/SKILLS from a previous install? Path [%s]: ' "$DEST" "$DEST" > /dev/tty
    IFS= read -r ANS < /dev/tty || ANS=""
    FROM="${ANS:-$DEST}"
  else
    printf 'Migrate KNOWLEDGE/MEMORY/SKILLS from a previous install? Path (blank to skip): ' > /dev/tty
    IFS= read -r FROM < /dev/tty || FROM=""
  fi
fi
if [ -n "$FROM" ]; then
  [ -d "$FROM" ] || { echo "ERROR: --from path does not exist: $FROM"; exit 1; }
  FROM="$(cd "$FROM" && pwd)"
  [ -f "$FROM/scripts/rebuild-index.sh" ] && [ -d "$FROM/KNOWLEDGE" ] || {
    echo "ERROR: --from path doesn't look like an .agentic_context install (missing scripts/rebuild-index.sh or KNOWLEDGE/): $FROM"; exit 1; }
fi

# --- in-place upgrade: back up the old install and clear its slot ---
# Two ways to end up "in place": --from already points at DEST itself (the
# ordinary re-run-here case, no extra flag needed), or --from points
# elsewhere and --in-place asks to relocate the fresh install onto it.
RELOCATE_TARGET=""
AUTO_INPLACE_BACKUP=""
if [ -n "$FROM" ] && [ "$FROM" = "$DEST" ]; then
  TS="$(date +%Y%m%d_%H%M%S)"
  AUTO_INPLACE_BACKUP="${DEST}.bak-${TS}"
  echo "• Backing up existing install: $DEST -> $AUTO_INPLACE_BACKUP"
  mv "$DEST" "$AUTO_INPLACE_BACKUP"
  FROM="$AUTO_INPLACE_BACKUP"
  IN_PLACE=1
elif [ -n "$FROM" ]; then
  if [ "$IN_PLACE" -eq 0 ] && [ "$ASSUME_YES" -eq 0 ] && [ -r /dev/tty ] && [ -t 1 ]; then
    printf 'Replace the old install in place (back it up, move the fresh install to %s)? [y/N]: ' "$FROM" > /dev/tty
    IFS= read -r ANS_INPLACE < /dev/tty || ANS_INPLACE=""
    case "$ANS_INPLACE" in [Yy]*) IN_PLACE=1 ;; esac
  fi
  [ "$IN_PLACE" -eq 1 ] && RELOCATE_TARGET="$FROM"
elif [ "$IN_PLACE" -eq 1 ]; then
  echo "ERROR: --in-place needs --from <path> (or an interactive migration path)"; exit 1
fi

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
# AGENTS.md/CLAUDE.md live inside .agentic_context/; MAIN_PROMPT.md,
# README.md, and the deep-reference doc live at the repo root (source repo
# keeps the latter at documents/REFERENCE.md; installed instances get it
# flat, alongside README.md, since they have no documents/ folder). All end
# up inside the installed folder.
for f in AGENTS.md CLAUDE.md; do
  cp "$SRC/$f" "$DEST/$f"
done
cp "$REPO/MAIN_PROMPT.md"         "$DEST/MAIN_PROMPT.md"
cp "$REPO/README.md"              "$DEST/README.md"
cp "$REPO/documents/REFERENCE.md" "$DEST/REFERENCE.md"
# REFERENCE.md's own links assume a documents/ subfolder (its home in the
# source repo); here it lands flat, alongside README.md/LICENSE, so those
# links need the leading "../" stripped back off. The image links stay
# dangling either way — install has never shipped the diagram SVGs.
sed -i.bak \
  -e 's|\](\.\./README\.md)|](README.md)|' \
  -e 's|\](\.\./LICENSE)|](LICENSE)|' \
  "$DEST/REFERENCE.md" && rm -f "$DEST/REFERENCE.md.bak"

# Every script, tests included (they are small and nothing loads them): the
# version manifest lists them all, and a script missing here is a script that
# silently never ships. VERSION/CHANGELOG/REQUIREMENTS/the manifest travel with them.
for s in "$SRC"/scripts/*.sh; do cp "$s" "$DEST/scripts/$(basename "$s")"; done
cp "$SRC/scripts/.system-manifest" "$DEST/scripts/.system-manifest"
for f in VERSION CHANGELOG.md REQUIREMENTS.md; do cp "$SRC/$f" "$DEST/$f"; done
chmod +x "$DEST/scripts/"*.sh
cp "$SRC/KNOWLEDGE/SKILL.md" "$DEST/KNOWLEDGE/SKILL.md"
cp "$SRC/MEMORY/SKILL.md"    "$DEST/MEMORY/SKILL.md"

# --- SKILLS: always copied in full (categories + every skill) ---
cp -R "$SRC/SKILLS" "$DEST/SKILLS"
rm -f "$DEST/SKILLS/INDEX.md"                       # regenerated below
find "$DEST" -name '.DS_Store' -delete 2>/dev/null || true
SKILL_COUNT=$(find "$DEST/SKILLS" -mindepth 2 -name SKILL.md | wc -l | tr -d ' ')

# --- migrate from a previous install, or seed dummy content ---
if [ -n "$FROM" ]; then
  echo "• Migrating content from $FROM"
  rm -rf "$DEST/KNOWLEDGE" "$DEST/MEMORY"
  cp -R "$FROM/KNOWLEDGE" "$DEST/KNOWLEDGE"
  cp -R "$FROM/MEMORY"    "$DEST/MEMORY"
  # SKILLS: keep the fresh meta/ (framework, already current); overlay every
  # other category from the old install, replacing the template version so the
  # project's own edits win.
  if [ -d "$FROM/SKILLS" ]; then
    for cat in "$FROM/SKILLS"/*/; do
      [ -d "$cat" ] || continue
      name="$(basename "$cat")"
      [ "$name" = "meta" ] && continue
      rm -rf "$DEST/SKILLS/$name"
      cp -R "$cat" "$DEST/SKILLS/$name"
    done
  fi
  # Preserve pending UNCONFIRMED judgment state; rebuild-index.sh below only
  # refreshes entries whose summary line actually changed.
  [ -f "$FROM/scripts/.summary-hashes" ] && cp "$FROM/scripts/.summary-hashes" "$DEST/scripts/.summary-hashes"
  find "$DEST" -name '.DS_Store' -delete 2>/dev/null || true
  MIGRATED=1
else
  MIGRATED=0
fi

# --- dummy KNOWLEDGE docs (delete once real content exists; skipped when --from migrated) ---
TODAY=$(date +%Y-%m-%d)
if [ "$MIGRATED" -eq 0 ]; then
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

# --- MEMORY slug map: one tab-separated row per MEMORY/<slug>/ folder; rebuild-index.sh
# prints it in the slim MEMORY/INDEX.md and warns about a folder with no row ---
printf 'example-topic\tDummy slug (delete me): replace with your first real topic folder\n' > "$DEST/MEMORY/SLUGS.tsv"

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
fi # MIGRATED

# --- build indexes + verify ---
echo "• Building indexes"
"$DEST/scripts/rebuild-index.sh"
echo "• Validating"
"$DEST/scripts/validate.sh"

# --- relocate onto the old install's path/name, if --in-place was requested
#     for a --from that pointed elsewhere (the "already in place" case above
#     never sets RELOCATE_TARGET, since DEST is already the right spot) ---
RELOCATE_BACKUP=""
if [ -n "$RELOCATE_TARGET" ]; then
  TS="$(date +%Y%m%d_%H%M%S)"
  RELOCATE_BACKUP="${RELOCATE_TARGET}.bak-${TS}"
  echo "• Relocating: backing up $RELOCATE_TARGET -> $RELOCATE_BACKUP, then moving the fresh install there"
  mv "$RELOCATE_TARGET" "$RELOCATE_BACKUP"
  mv "$DEST" "$RELOCATE_TARGET" 2>/dev/null || { cp -R "$DEST" "$RELOCATE_TARGET" && rm -rf "$DEST"; }
  DEST="$RELOCATE_TARGET"
  CTX_NAME="$(basename "$DEST")"
fi

HIDDEN_NOTE="hidden"; [ "${CTX_NAME#.}" = "$CTX_NAME" ] && HIDDEN_NOTE="visible"
echo
echo "DONE — installed at $DEST"
echo "  Context folder:      $CTX_NAME/ ($HIDDEN_NOTE)"
[ "$CTX_NAME" = "$DEFAULT_NAME" ] && \
  echo "                       default — override with: --dir <name> [--visible]"
echo "  Skills copied:       $SKILL_COUNT"
if [ -n "$RELOCATE_BACKUP" ]; then
  echo "  Upgraded in place:   old install at $RELOCATE_TARGET backed up to $RELOCATE_BACKUP"
  echo "  (KNOWLEDGE, MEMORY, and non-meta SKILLS carried over; no dummy content seeded.)"
elif [ -n "$AUTO_INPLACE_BACKUP" ]; then
  echo "  Upgraded in place:   old install backed up to $AUTO_INPLACE_BACKUP"
  echo "  (KNOWLEDGE, MEMORY, and non-meta SKILLS carried over; no dummy content seeded.)"
elif [ "$MIGRATED" -eq 1 ]; then
  echo "  Migrated from:       $FROM"
  echo "  (KNOWLEDGE, MEMORY, and non-meta SKILLS carried over; no dummy content seeded.)"
else
  echo "  Dummy KNOWLEDGE:     2 (marked 'delete me' — replace with real docs)"
  echo "  Dummy MEMORY:        2 (marked 'delete me' — replace with real findings)"
fi
echo
echo "Next steps:"
echo "  1. Paste $DEST/MAIN_PROMPT.md at the start of each agent session."
echo "     (It finds its own root by content, so the folder name is free."
echo "      Rename $CTX_NAME/ whenever you like — nothing to re-edit.)"
if [ "$MIGRATED" -eq 0 ]; then
  echo "  2. Replace the dummy docs/findings, then run scripts/rebuild-index.sh."
fi
fi # WANT_PROMPT

# --- MCP server: copy, venv, pip install ---
if [ "$WANT_MCP" -eq 1 ]; then
  MCP_SRC="$REPO/mcp_server"
  [ -d "$MCP_SRC" ] || { echo "ERROR: mcp_server/ not found in this repo: $MCP_SRC"; exit 1; }
  MCP_DEST="$TARGET/mcp_server"
  if [ -e "$MCP_DEST" ] && [ "$FORCE" -ne 1 ]; then
    echo "ERROR: $MCP_DEST already exists. Re-run with --force to overwrite it."
    exit 1
  fi
  [ -e "$MCP_DEST" ] && rm -rf "$MCP_DEST"
  echo "• Installing MCP server → $MCP_DEST"
  mkdir -p "$MCP_DEST"
  cp -R "$MCP_SRC/agentic_context_mcp" "$MCP_DEST/agentic_context_mcp"
  cp "$MCP_SRC/pyproject.toml" "$MCP_DEST/pyproject.toml"
  cp "$MCP_SRC/README.md"      "$MCP_DEST/README.md"
  find "$MCP_DEST" -name '__pycache__' -o -name '.DS_Store' | xargs rm -rf 2>/dev/null || true

  command -v python3 >/dev/null || { echo "ERROR: python3 is required to set up the MCP server venv"; exit 1; }
  echo "• Creating venv and installing agentic_context_mcp"
  python3 -m venv "$MCP_DEST/.venv"
  "$MCP_DEST/.venv/bin/pip" install -q --upgrade pip
  "$MCP_DEST/.venv/bin/pip" install -q -e "$MCP_DEST"
  MCP_INSTALLED=1
else
  MCP_INSTALLED=0
fi

if [ "$MCP_INSTALLED" -eq 1 ]; then
  echo
  echo "MCP server installed at $TARGET/mcp_server"
  echo "  Venv:  $TARGET/mcp_server/.venv"
  echo "  Verify it runs standalone: $TARGET/mcp_server/.venv/bin/python -m agentic_context_mcp.server"
  echo "  (should hang waiting on stdin — Ctrl-C to stop; that's correct with no client attached)"
  echo "  Next: wire it into a client's config (command = that venv's python, args = [-m, agentic_context_mcp.server, <root>])."
  echo "  See $TARGET/mcp_server/README.md, or this repo's documents/MCP_SERVER_INSTALL.md for the full Claude Desktop walkthrough."
fi
