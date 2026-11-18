#!/usr/bin/env bash
# summary: Regenerates the KNOWLEDGE, MEMORY (slim INDEX.md + INDEX.full.md) and SKILLS INDEX.md files from each item's own summary; run by hand after adding or editing a doc.
# Regenerates the three INDEX.md files from each item's own summary.
#   KNOWLEDGE / MEMORY : `> summary:` line inside each .md  (source of truth)
#   SKILLS             : frontmatter `description:` inside each SKILL.md (native)
# Files are the source of truth; indexes are derived. Never hand-edit an INDEX as authority.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f scripts/lib.sh ] || { echo "ERROR: scripts/lib.sh is missing: copy the whole scripts/ folder, not single scripts (or re-run the installer)" >&2; exit 2; }
. scripts/lib.sh
DATE=$(date +%Y-%m-%d)
# System version stamp for every derived header (R23); absent on an install with no VERSION file.
VER=$(head -n1 VERSION 2>/dev/null | tr -d '[:space:]' || true)
STAMP=""; [ -n "$VER" ] && STAMP=" System v${VER}."

tok_of () { # $1 file → estimated context cost to load it (size ÷ 4, ~4 chars/token)
  local t=$(( $(wc -c < "$1") / 4 ))
  if [ "$t" -ge 1000 ]; then echo "$((t/1000)).$(((t%1000)/100))k"; else echo "$t"; fi
}

# --- docs-style folders (any depth: <root>/**/<file>.md) ---
# Groups files by their parent directory relative to $root. A file at
# $root/a/b/c.md is bucketed under group "a/b" and listed as "a/b/c.md".
build_docs () { # $1 root  $2 help line
  local root=$1 out="${3:-$1/INDEX.md}" stale=""
  {
    echo "# ${root} — Index"; echo
    echo "> DERIVED from each doc's \`> summary:\` line. Rebuilt: ${DATE}. Run \`./scripts/rebuild-index.sh\`.${STAMP}"
    echo "> \`(~N tok)\` = estimated context cost to open that doc (size ÷ 4)."; echo
    echo "$2"

    # Collect every group (relative subpath under $root that contains ≥1 .md).
    # Sort ensures deterministic + human-friendly ordering.
    local groups=()
    while IFS= read -r rel; do
      groups+=("$rel")
    done < <(
      find "$root" -mindepth 2 -type f -name '*.md' ! -name 'INDEX*.md' -exec dirname {} \; \
        | sed "s|^$root/||" \
        | sort -u
    )

    # One awk pass reads every doc's header fields (scripts/lib.sh); the loop
    # below then runs on shell builtins only. Files are listed group by group,
    # in glob order, so the rows arrive in the order they are printed.
    local last="" grp f bytes nsum sum after hasu used rep kw hasv ver t tok n tag line
    while IFS=$US read -r f bytes nsum sum after hasu used rep kw hasv ver; do
      grp=${f%/*}; grp=${grp#"$root"/}
      [ "$grp" = "$last" ] || { echo; echo "## ${grp}/"; last=$grp; }
      [ "$nsum" -gt 0 ] || sum=""
      tag=""
      if [ "$root" = "MEMORY" ] && [ -n "$used" ]; then
        # promotion is DERIVED too: >=3 distinct `**Used in:**` domains = generality proven by use
        case "$sum" in
          # Prefixes carry an explanation after the keyword ("[STALE — superseded by …]"),
          # so match the opening bracket only, never a closing "]".
          "[STALE"*|"[PROMOTE?"*|"[REVIEWED"*) ;;  # superseded, already flagged, or judged and settled
          *) n=$(printf '%s\n' "$used" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' | sort -u | wc -l | tr -d ' ' || true)
             [ "${n:-0}" -ge 3 ] && tag="[PROMOTE? auto — used in ${n} domains] " ;;
        esac
      fi
      t=$((bytes / 4))
      if [ "$t" -ge 1000 ]; then tok="$((t/1000)).$(((t%1000)/100))k"; else tok=$t; fi
      # Optional search terms the summary does not contain (R28); memory-find.sh matches the whole line.
      line="- \`${f#"$root"/}\` — ${tag}${sum:-(no summary line)}${kw:+ [kw: ${kw}]} (~${tok} tok)"
      case "$sum" in
        "[STALE"*) # point at the replacement when the finding names one
                   [ -n "$rep" ] && line+=" -> ${rep}"
                   stale+="$line"$'\n' ;;    # superseded → tail section, out of the active list
        *)          echo "$line" ;;
      esac
    done < <(
      for grp in "${groups[@]+"${groups[@]}"}"; do
        [ -n "$grp" ] || continue
        # .md files directly inside this group folder (deeper files belong to a deeper group of their own).
        for f in "$root/$grp"/*.md; do
          [ -e "$f" ] || continue
          [ "$(basename "$f")" = "INDEX.md" ] && continue
          echo "$f"
        done
      done | scan_docs
    )
    if [ -n "$stale" ]; then
      echo; echo "## superseded/ (historical — skip unless auditing)"
      printf '%s' "$stale"
    fi
  } > "$out.tmp" && mv "$out.tmp" "$out"; echo "wrote $out"
}

# --- skills folder (nested: SKILLS/<category>/<skill>/SKILL.md) ---
build_skills () {
  local root="SKILLS" out="SKILLS/INDEX.md"
  {
    echo "# SKILLS — Index"; echo
    echo "> DERIVED from each skill's frontmatter \`description:\`. Rebuilt: ${DATE}. Run \`./scripts/rebuild-index.sh\`.${STAMP}"
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
  } > "$out.tmp" && mv "$out.tmp" "$out"; echo "wrote $out"
}

# --- summary-confirmation cache (semantic-staleness support) ---
# scripts/.summary-hashes: one line per indexed file — summary-line hash, body
# hash (file minus that line), path — tab-separated. An entry refreshes when the
# file is new or its summary line changed (editing a summary = confirming it).
# A body-only change keeps the old entry, so validate.sh can flag "body changed
# since summary last confirmed". Confirm without editing: scripts/confirm-summary.sh.
# The cache is judgment state, not derivable from the files — commit it.
CACHE="scripts/.summary-hashes"

update_cache () {
  local tmp="${CACHE}.tmp"
  [ -e "$CACHE" ] || : > "$CACHE"
  { find KNOWLEDGE MEMORY -mindepth 2 -type f -name '*.md' ! -name 'INDEX*.md' 2>/dev/null
    find SKILLS -mindepth 3 -maxdepth 3 -type f -name 'SKILL.md' 2>/dev/null; } | sort | hash_table \
    | awk -F'\t' -v c="$CACHE" '
        # getline, not the NR==FNR idiom: that one misreads every row when the cache is still empty.
        BEGIN { while ((getline l < c) > 0) { split(l, a, "\t"); if (!(a[3] in old)) { old[a[3]] = l; os[a[3]] = a[1] } } }
        { if (($3 in old) && os[$3] == $1) print old[$3]   # body-only drift stays visible
          else print }                                     # new or summary edited → (re)confirm
      ' > "$tmp"
  mv "$tmp" "$CACHE"; echo "wrote $CACHE"
}

build_docs KNOWLEDGE "**Load at session start.** Read a doc only on summary match. \`[CORE]\` = always loaded."
# MEMORY is two-tier: INDEX.full.md (every finding's summary, never loaded at init, searched via
# scripts/memory-find.sh) and a tiny INDEX.md (slug map + promotion candidates) that is loaded.
# Full is written first so INDEX.md ends up the newest file (validate.sh freshness check).
build_docs MEMORY    "Full catalogue — **do not load whole**; search it with \`scripts/memory-find.sh <keywords>\`. \`[PROMOTE?]\` = candidate for KNOWLEDGE (hand-flagged, or auto at ≥3 used-in domains)." MEMORY/INDEX.full.md

build_memory_stub () {
  local out="MEMORY/INDEX.md" full="MEMORY/INDEX.full.md" missing=0 d slug n blurb
  {
    echo "# MEMORY — Index (slim)"; echo
    echo "> DERIVED. Rebuilt: ${DATE}. Run \`./scripts/rebuild-index.sh\`.${STAMP} Full catalogue: \`MEMORY/INDEX.full.md\` (never load whole)."; echo
    echo "**What this is:** dated findings (gotchas, fixes, quirks) too narrow for KNOWLEDGE. Only this slug map is loaded at init."
    echo "**When to look:** before investigating a symptom, or when the user says \"again\", \"still\", \"back\", \"used to work\"; and after KNOWLEDGE didn't answer."
    echo "**How:** \`scripts/memory-find.sh <keyword> [keyword…]\` (case-insensitive, all keywords must match, max 15 hits; \`[ARCHIVE]\` slugs only with \`--all\`) → open a finding only on summary match. Never \`cat\` the full index."
    echo; echo "## Slugs"
    local any=0
    for d in MEMORY/*/; do
      [ -d "$d" ] || continue                 # no slug folders: the glob stays literal
      any=1
      slug=$(basename "$d")
      n=$(find "$d" -type f -name '*.md' | wc -l | tr -d ' ')
      blurb=$(awk -F'\t' -v s="$slug" '$1==s{print $2}' MEMORY/SLUGS.tsv 2>/dev/null)
      [ -n "$blurb" ] || { echo "WARN: MEMORY/SLUGS.tsv has no row for '${slug}'" >&2; blurb="(no description — add a row to MEMORY/SLUGS.tsv)"; }
      echo "- \`${slug}/\` — ${n} findings — ${blurb}"
    done
    [ "$any" -eq 1 ] || echo "(no slug folders yet — create MEMORY/<slug>/ and run scripts/set-slug.sh)"
    echo; echo "## Promotion candidates"
    grep -F "\` — [PROMOTE?" "$full" || echo "(none)"
  } > "$out.tmp" && mv "$out.tmp" "$out"; echo "wrote $out"
}
build_memory_stub
build_skills
update_cache
