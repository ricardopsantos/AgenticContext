#!/usr/bin/env bash
# Regenerates the three INDEX.md files from each item's own summary.
#   KNOWLEDGE / MEMORY : `> summary:` line inside each .md  (source of truth)
#   SKILLS             : frontmatter `description:` inside each SKILL.md (native)
# Files are the source of truth; indexes are derived. Never hand-edit an INDEX as authority.
set -euo pipefail
cd "$(dirname "$0")/.."
DATE=$(date +%Y-%m-%d)

tok_of () { # $1 file → estimated context cost to load it (size ÷ 4, ~4 chars/token)
  local t=$(( $(wc -c < "$1") / 4 ))
  if [ "$t" -ge 1000 ]; then echo "$((t/1000)).$(((t%1000)/100))k"; else echo "$t"; fi
}

# --- docs-style folders (any depth: <root>/**/<file>.md) ---
# Groups files by their parent directory relative to $root. A file at
# $root/a/b/c.md is bucketed under group "a/b" and listed as "a/b/c.md".
build_docs () { # $1 root  $2 help line
  local root=$1 out="$1/INDEX.md" stale=""
  {
    echo "# ${root} — Index"; echo
    echo "> DERIVED from each doc's \`> summary:\` line. Rebuilt: ${DATE}. Run \`./scripts/rebuild-index.sh\`."
    echo "> \`(~N tok)\` = estimated context cost to open that doc (size ÷ 4)."; echo
    echo "$2"

    # Collect every group (relative subpath under $root that contains ≥1 .md).
    # Sort ensures deterministic + human-friendly ordering.
    local groups=()
    while IFS= read -r rel; do
      groups+=("$rel")
    done < <(
      find "$root" -mindepth 2 -type f -name '*.md' ! -name 'INDEX.md' -print0 \
        | xargs -0 -n1 dirname \
        | sed "s|^$root/||" \
        | sort -u
    )

    for grp in "${groups[@]}"; do
      [ -n "$grp" ] || continue
      echo; echo "## ${grp}/"
      # Walk .md files directly inside this group folder (not deeper —
      # deeper files belong to a deeper group of their own).
      for f in "$root/$grp"/*.md; do
        [ -e "$f" ] || continue
        [ "$(basename "$f")" = "INDEX.md" ] && continue
        sum=$(grep -m1 '^> summary:' "$f" 2>/dev/null | sed 's/^> summary: //' || true)
        tag=""
        if [ "$root" = "MEMORY" ]; then
          # promotion is DERIVED too: >=3 distinct `**Used in:**` domains = generality proven by use
          used=$(grep -m1 '^\*\*Used in:\*\*' "$f" 2>/dev/null | sed 's/^\*\*Used in:\*\* *//' || true)
          if [ -n "$used" ]; then
            n=$(printf '%s\n' "$used" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' | sort -u | wc -l | tr -d ' ' || true)
            case "$sum" in
              "[STALE]"*|"[PROMOTE?"*) ;;      # already flagged by hand or superseded
              *) [ "${n:-0}" -ge 3 ] && tag="[PROMOTE? auto — used in ${n} domains] " ;;
            esac
          fi
        fi
        line="- \`${f#"$root"/}\` — ${tag}${sum:-(no summary line)} (~$(tok_of "$f") tok)"
        case "$sum" in
          "[STALE]"*) stale+="$line"$'\n' ;;   # superseded → tail section, out of the active list
          *)          echo "$line" ;;
        esac
      done
    done
    if [ -n "$stale" ]; then
      echo; echo "## superseded/ (historical — skip unless auditing)"
      printf '%s' "$stale"
    fi
  } > "$out"; echo "wrote $out"
}

# --- skills folder (nested: SKILLS/<category>/<skill>/SKILL.md) ---
build_skills () {
  local root="SKILLS" out="SKILLS/INDEX.md"
  {
    echo "# SKILLS — Index"; echo
    echo "> DERIVED from each skill's frontmatter \`description:\`. Rebuilt: ${DATE}. Run \`./scripts/rebuild-index.sh\`."
    echo "> \`(~N tok)\` = estimated context cost to open that skill (size ÷ 4)."; echo
    echo "**Know they exist via this list. Load a skill's SKILL.md only when its description matches the task.**"
    for cat in "$root"/*/; do
      [ -d "$cat" ] || continue
      echo; echo "## $(basename "$cat")/"
      for sk in "$cat"*/; do
        [ -d "$sk" ] || continue
        sf="${sk}SKILL.md"; [ -e "$sf" ] || continue
        desc=$(grep -m1 '^description:' "$sf" 2>/dev/null | sed 's/^description: *//' || true)
        echo "- \`${sk#"$root"/}\` — ${desc:-(no description)} (~$(tok_of "$sf") tok)"
      done
    done
  } > "$out"; echo "wrote $out"
}

# --- summary-confirmation cache (semantic-staleness support) ---
# scripts/.summary-hashes: one line per indexed file — summary-line hash, body
# hash (file minus that line), path — tab-separated. An entry refreshes when the
# file is new or its summary line changed (editing a summary = confirming it).
# A body-only change keeps the old entry, so validate.sh can flag "body changed
# since summary last confirmed". Confirm without editing: scripts/confirm-summary.sh.
# The cache is judgment state, not derivable from the files — commit it.
CACHE="scripts/.summary-hashes"

summary_line_of () {
  case "$1" in
    SKILLS/*) grep -m1 '^description:' "$1" 2>/dev/null || true ;;
    *)        grep -m1 '^> summary:'   "$1" 2>/dev/null || true ;;
  esac
}
body_hash_of () { # hash of the file with its summary/description line removed
  case "$1" in
    SKILLS/*) grep -v '^description:' "$1" ;;
    *)        grep -v '^> summary:'   "$1" ;;
  esac | shasum -a 256 | cut -d' ' -f1
}
hash_str () { printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1; }

update_cache () {
  local tmp="${CACHE}.tmp" f s b old
  : > "$tmp"
  while IFS= read -r f; do
    s=$(hash_str "$(summary_line_of "$f")")
    b=$(body_hash_of "$f")
    old=""
    [ -e "$CACHE" ] && old=$(awk -F'\t' -v p="$f" '$3==p' "$CACHE" | head -1)
    if [ -z "$old" ] || [ "${old%%$'\t'*}" != "$s" ]; then
      printf '%s\t%s\t%s\n' "$s" "$b" "$f" >> "$tmp"   # new or summary edited → (re)confirm
    else
      printf '%s\n' "$old" >> "$tmp"                    # body-only drift stays visible
    fi
  done < <(
    { find KNOWLEDGE MEMORY -mindepth 2 -type f -name '*.md' ! -name 'INDEX.md' 2>/dev/null
      find SKILLS -mindepth 3 -maxdepth 3 -type f -name 'SKILL.md' 2>/dev/null; } | sort
  )
  mv "$tmp" "$CACHE"; echo "wrote $CACHE"
}

build_docs KNOWLEDGE "**Load at session start.** Read a doc only on summary match. \`[CORE]\` = always loaded."
build_docs MEMORY    "**Names only at init.** Consult when a slug is relevant and KNOWLEDGE didn't answer. \`[PROMOTE?]\` = candidate for KNOWLEDGE (hand-flagged, or auto at ≥3 used-in domains)."
build_skills
update_cache
