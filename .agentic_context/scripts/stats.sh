#!/usr/bin/env bash
# summary: Read-only size/count stats for KNOWLEDGE, MEMORY and SKILLS plus the estimated token cost of the bootstrap load; run by hand at session start.
# Size/count stats for KNOWLEDGE, MEMORY, SKILLS: folder counts, file counts,
# average/biggest/smallest folder and file. Read-only, modifies nothing.
set -uo pipefail
cd "$(dirname "$0")/.."

human () { # $1 = bytes -> human readable
  awk -v b="$1" 'BEGIN{
    split("B KB MB GB", u, " ")
    i=1
    while (b >= 1024 && i < 4) { b/=1024; i++ }
    printf "%.1f%s", b, u[i]
  }'
}

section () {
  local root="$1"
  [ -d "$root" ] || return
  echo "== $root =="

  # topic folders = depth-1 subdirs (skip the root itself)
  local folders
  # -L: SKILLS categories may be symlinks into a shared skills repo.
  folders=$(find -L "$root" -mindepth 1 -maxdepth 1 -type d)
  local nfolders
  nfolders=$(printf '%s\n' "$folders" | grep -c . || true)

  # docs = *.md files, excluding INDEX.md/SKILL.md housekeeping files
  # SKILLS docs are the SKILL.md files themselves (category/skill/SKILL.md), so count those instead.
  local files
  if [ "$root" = SKILLS ]; then
    files=$(find -L "$root" -mindepth 3 -type f -name 'SKILL.md')
  else
    files=$(find "$root" -mindepth 2 -type f -name '*.md' ! -name 'INDEX*.md' ! -name 'SKILL.md')
  fi
  local nfiles
  nfiles=$(printf '%s\n' "$files" | grep -c . || true)

  echo "  folders: $nfolders   files: $nfiles"

  if [ "$nfolders" -gt 0 ]; then
    local fsizes total_fsz avg_fsz big_f small_f
    fsizes=$(printf '%s\n' "$folders" | while read -r d; do
      sz=$(du -sk "$d" 2>/dev/null | cut -f1)
      echo "$((sz*1024)) $d"
    done)
    total_fsz=$(printf '%s\n' "$fsizes" | awk '{s+=$1} END{print s+0}')
    avg_fsz=$((total_fsz / nfolders))
    big_f=$(printf '%s\n' "$fsizes" | sort -rn | head -1)
    small_f=$(printf '%s\n' "$fsizes" | sort -n | head -1)
    echo "  avg folder size: $(human "$avg_fsz")"
    echo "  biggest folder:  $(human "$(echo "$big_f" | cut -d' ' -f1)")  ($(echo "$big_f" | cut -d' ' -f2-))"
    echo "  smallest folder: $(human "$(echo "$small_f" | cut -d' ' -f1)")  ($(echo "$small_f" | cut -d' ' -f2-))"
  fi

  if [ "$nfiles" -gt 0 ]; then
    local sizes total_sz avg_sz big small
    sizes=$(printf '%s\n' "$files" | while read -r f; do
      sz=$(wc -c < "$f" | tr -d ' ')
      echo "$sz $f"
    done)
    total_sz=$(printf '%s\n' "$sizes" | awk '{s+=$1} END{print s+0}')
    avg_sz=$((total_sz / nfiles))
    big=$(printf '%s\n' "$sizes" | sort -rn | head -1)
    small=$(printf '%s\n' "$sizes" | sort -n | head -1)
    echo "  avg file size:   $(human "$avg_sz")"
    echo "  biggest file:    $(human "$(echo "$big" | cut -d' ' -f1)")  ($(echo "$big" | cut -d' ' -f2-))"
    echo "  smallest file:   $(human "$(echo "$small" | cut -d' ' -f1)")  ($(echo "$small" | cut -d' ' -f2-))"
  fi
  echo
}

# System version first: every session's pasted stats say which version produced them (R23).
echo "== SYSTEM =="
echo "  version: $(head -n1 VERSION 2>/dev/null | tr -d '[:space:]' | grep . || echo 'none (no VERSION file)')   system files: $(wc -l < scripts/.system-manifest 2>/dev/null | tr -d ' ' | grep . || echo 0)"
echo

section KNOWLEDGE
section MEMORY
section SKILLS

# Bootstrap cost: est. tokens = bytes ÷ 4 (same rule as rebuild-index.sh), not an exact tokenizer count.
bootstrap_cost () {
  local total=0 n=0
  row () { # $1 = label, $2 = file
    [ -f "$2" ] || { printf '%7s  %s  (MISSING)\n' "-" "$1"; return; }
    n=$((n + 1))
    local t=$(( $(wc -c < "$2") / 4 ))
    total=$((total + t))
    printf '%7d  %s\n' "$t" "$1"
  }
  echo "== BOOTSTRAP LOAD: every file read, paths relative to <root> (est. tokens) =="
  # The bootstrap prompt: MAIN_PROMPT.md inside the root (every installer puts it there),
  # else a context.md beside the root (an instance kept as a subfolder of a repo that
  # holds the prompt at its top). Inside first, so an unrelated project file is never picked.
  BOOT=""
  for c in MAIN_PROMPT.md ../context.md; do [ -f "$c" ] && { BOOT=$c; break; }; done
  [ -n "$BOOT" ] && row "$(basename "$BOOT")" "$BOOT"
  row "AGENTS.md"            "AGENTS.md"
  row "CLAUDE.md"            "CLAUDE.md"
  # Optional extras: counted only when this install has them.
  for pf in POLICIES/*.md; do [ -f "$pf" ] && row "$pf" "$pf"; done
  row "KNOWLEDGE/SKILL.md"   "KNOWLEDGE/SKILL.md"
  row "KNOWLEDGE/INDEX.md"   "KNOWLEDGE/INDEX.md"
  row "MEMORY/SKILL.md"      "MEMORY/SKILL.md"
  row "MEMORY/INDEX.md"      "MEMORY/INDEX.md"
  row "SKILLS/SKILL.md"      "SKILLS/SKILL.md"
  row "SKILLS/INDEX.md"      "SKILLS/INDEX.md"
  [ -f "$HOME/FOLDER-INDEX.md" ] && row "~/FOLDER-INDEX.md" "$HOME/FOLDER-INDEX.md"
  # [CORE] KNOWLEDGE docs are loaded at start; names come from the index.
  while read -r f; do row "KNOWLEDGE/$f [CORE]" "KNOWLEDGE/$f"; done < <(
    grep '\[CORE\]' KNOWLEDGE/INDEX.md | sed -n 's/^- `\([^`]*\)`.*/\1/p')
  # Drift check: root-level .md files that the bootstrap prompt names but the list above doesn't cover.
  local drift=""   # CHANGELOG.md is exempt: the prompt names it as history, it is never loaded
  while read -r m; do
    [ -f "$m" ] || continue
    case " AGENTS.md CLAUDE.md MAIN_PROMPT.md CHANGELOG.md " in *" $m "*) continue ;; esac
    drift="$drift $m"
  done < <([ -n "$BOOT" ] && grep -o '`\(<root>/\)\?[A-Za-z_]*\.md`' "$BOOT" | tr -d '`' | sed 's|<root>/||' | sort -u)
  echo "-------"
  [ -n "$drift" ] && echo "WARNING: the bootstrap prompt names root files not in this list:$drift"
  printf '%7d  TOTAL (%d files read at bootstrap)\n' "$total" "$n"
  echo "Excludes: tool-call output (pull/validate/stats), system prompt, auto-memory MEMORY.md."
}

bootstrap_cost
