#!/usr/bin/env bash
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
  folders=$(find "$root" -mindepth 1 -maxdepth 1 -type d)
  local nfolders
  nfolders=$(printf '%s\n' "$folders" | grep -c . || true)

  # docs = *.md files, excluding INDEX.md always. SKILL.md is content in
  # SKILLS/ (the only file each skill folder has) but housekeeping elsewhere.
  local files
  if [ "$root" = "SKILLS" ]; then
    files=$(find "$root" -mindepth 2 -type f -name 'SKILL.md')
  else
    files=$(find "$root" -mindepth 2 -type f -name '*.md' ! -name 'INDEX.md' ! -name 'SKILL.md')
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

section KNOWLEDGE
section MEMORY
section SKILLS
