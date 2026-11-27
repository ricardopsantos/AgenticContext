#!/usr/bin/env bash
# summary: Read-only integrity check of KNOWLEDGE/MEMORY/SKILLS (summaries, strays, index freshness); run at session start and after edits.
# Integrity check (does NOT modify anything). Run it on init or any time.
# Flags: docs missing/empty/multi-line `> summary:`, skills missing `description:`,
#        stray files the index script can't see, and indexes older than their content.
# It can't judge whether a summary is *accurate* — but it WARNS (UNCONFIRMED) when a
# doc's body changed since its summary was last confirmed (see scripts/.summary-hashes).
# --content : content checks only, skip index freshness (use right after writing
#             a file, before the rebuild — freshness would false-flag STALE there).
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
content_only=0
# Summary caps (R25). MEMORY_CAP_SINCE: filename date (YYYYMMDD) from which the MEMORY cap is enforced per file.
SUMMARY_MAX=${AGENTIC_SUMMARY_MAX:-200}
SKILL_DESC_MAX=${AGENTIC_SKILL_DESC_MAX:-300}
MEMORY_SUMMARY_MAX=${AGENTIC_MEMORY_SUMMARY_MAX:-300}
MEMORY_CAP_SINCE=${AGENTIC_MEMORY_CAP_SINCE:-20261116}
[ "${1:-}" = "--content" ] && content_only=1

[ -f scripts/lib.sh ] || { echo "ERROR: scripts/lib.sh is missing: copy the whole scripts/ folder, not single scripts (or re-run the installer)" >&2; exit 2; }
. scripts/lib.sh
# One pass over every doc (R31); the checks below loop over these rows with shell builtins.
DOCS=$(find KNOWLEDGE MEMORY -mindepth 2 -type f -name '*.md' ! -name 'INDEX.md' ! -name 'INDEX.full.md' ! -name 'SKILL.md' 2>/dev/null | sort | scan_docs)

echo "• KNOWLEDGE + MEMORY — every doc has a one-line '> summary:'"
while IFS= read -r f; do                      # an empty file has no row in $DOCS
  echo "  MISSING summary : $f"; fail=1
done < <(find KNOWLEDGE MEMORY -mindepth 2 -type f -name '*.md' -empty 2>/dev/null | sort)
while IFS=$US read -r f bytes nsum sum after hasu used sup kw hasv ver; do
  [ -n "$f" ] || continue
  if [ "$nsum" -eq 0 ]; then echo "  MISSING summary : $f"; fail=1; continue; fi
  case "$sum" in
    "> summary:"|"") echo "  EMPTY   summary : $f"; fail=1; continue ;;
  esac
  [ -n "${sum// /}" ] || { echo "  EMPTY   summary : $f"; fail=1; continue; }
  # summary must be exactly one line: the line right after it must be blank
  case "$after" in "> keywords:"*) after="" ;; esac   # R35: keywords may follow the summary
  [ -z "$after" ] || { echo "  MULTILINE summary (line after '> summary:' must be blank): $f"; fail=1; }
done <<<"$DOCS"

echo "• MEMORY — 'Used in:' lines well-formed (when present)"
while IFS=$US read -r f bytes nsum sum after hasu used sup kw hasv ver; do
  case "$f" in MEMORY/*) ;; *) continue ;; esac
  [ "$hasu" = 1 ] || continue
  if [ -z "$used" ]; then
    echo "  EMPTY 'Used in:' line: $f"; fail=1; continue
  fi
  dups=$(printf '%s\n' "$used" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' | sort | uniq -d)
  if [ -n "$dups" ]; then
    echo "  DUPLICATE domain(s) in 'Used in:' [$(echo $dups | tr '\n' ' ')]: $f"; fail=1
  fi
done <<<"$DOCS"

echo "• MEMORY — [STALE — superseded…] findings name their replacement (warning only)"
swarn=0
resolve_finding () { # $1 = referencing file, $2 = target as written; prints the path of an existing MEMORY finding
  local t=$2 c
  for c in "$(dirname "$1")/$t" "MEMORY/$t" "$t"; do [ -f "$c" ] && { echo "$c"; return; }; done
  find MEMORY -type f -path "*/$t" 2>/dev/null | head -1
}
while IFS=$US read -r f bytes nsum sum after hasu used sup kw hasv ver; do
  case "$f" in MEMORY/*) ;; *) continue ;; esac
  case "$sum" in "[STALE — superseded"*) ;; *) continue ;; esac
  tgt=${sup#\`}; tgt=${tgt%%\`*}
  if [ -z "$tgt" ]; then
    echo "  NO 'Superseded-by:' on a [STALE — superseded…] finding: $f"; swarn=1; continue
  fi
  case "$tgt" in *.md) ;; *) continue ;; esac     # a non-file replacement (e.g. a rule) has nothing to back-link
  dest=$(resolve_finding "$f" "$tgt")
  if [ -z "$dest" ]; then
    echo "  'Superseded-by:' target missing ($tgt): $f"; swarn=1
  elif [ "${dest#MEMORY/}" != "$dest" ] && ! grep '^\*\*Corrects:\*\*' "$dest" | grep -qF "$(basename "$f")"; then
    echo "  replacement lacks back-link 'Corrects: $(basename "$f")': $dest"; swarn=1
  fi
done <<<"$DOCS"

echo "• MEMORY — SLUGS.tsv rows match the MEMORY/<slug>/ folders (warning only)"
for d in MEMORY/*/; do
  [ -d "$d" ] || continue
  sl=$(basename "$d")
  awk -F'\t' -v s="$sl" '$1==s{f=1} END{exit !f}' MEMORY/SLUGS.tsv 2>/dev/null \
    || { echo "  no SLUGS.tsv row for MEMORY/$sl/ — run scripts/set-slug.sh $sl \"<description>\""; swarn=1; }
done
if [ -f MEMORY/SLUGS.tsv ]; then
  while IFS=$'\t' read -r sl _; do
    [ -n "$sl" ] || continue
    [ -d "MEMORY/$sl" ] || { echo "  SLUGS.tsv row '$sl' has no MEMORY/$sl/ folder"; swarn=1; }
  done < MEMORY/SLUGS.tsv
fi

echo "• Summary length — KNOWLEDGE ≤ $SUMMARY_MAX, skill descriptions ≤ $SKILL_DESC_MAX, new MEMORY findings ≤ $MEMORY_SUMMARY_MAX characters (warning only)"
# KNOWLEDGE/INDEX.md and SKILLS/INDEX.md are read whole at every bootstrap, so a
# paragraph-long summary is paid for in every session (R25).
old_long=0
while IFS=$US read -r f bytes nsum sum after hasu used sup kw hasv ver; do
  case "$f" in
    KNOWLEDGE/*)
      [ "${#sum}" -le "$SUMMARY_MAX" ] || { echo "  LONG summary (${#sum} chars, max $SUMMARY_MAX; keep the routing line, move detail into the body): $f"; swarn=1; } ;;
    MEMORY/*)
      # Searched, not loaded, so the cap is looser, and findings dated before the
      # rule are only counted: rewriting hundreds of old summaries buys nothing,
      # and a warning that never clears gets ignored.
      [ "${#sum}" -le "$MEMORY_SUMMARY_MAX" ] && continue
      d=${f##*/}; d=${d:0:8}
      if [[ "$d" =~ ^[0-9]{8}$ ]] && [ "$d" -lt "$MEMORY_CAP_SINCE" ]; then old_long=$((old_long + 1))
      else echo "  LONG summary (${#sum} chars, max $MEMORY_SUMMARY_MAX): $f"; swarn=1; fi ;;
  esac
done <<<"$DOCS"
# R35: keywords are searched, not loaded, but a keyword list that grows into a paragraph stops narrowing a search.
while IFS=$US read -r f bytes nsum sum after hasu used sup kw hasv ver; do
  [ "${#kw}" -le "${KEYWORDS_MAX:-150}" ] || { echo "  LONG keywords (${#kw} chars, max ${KEYWORDS_MAX:-150}; keep the words a search would use): $f"; swarn=1; }
done <<<"$DOCS"
[ "$old_long" -eq 0 ] || echo "  ($old_long MEMORY findings dated before $MEMORY_CAP_SINCE are over the cap; left as they are)"
while IFS= read -r line; do
  f=${line%%:*}; s=${line#*:description:}; s=${s# }
  [ "${#s}" -le "$SKILL_DESC_MAX" ] || { echo "  LONG description (${#s} chars, max $SKILL_DESC_MAX): $f"; swarn=1; }
done < <(find -L SKILLS -mindepth 3 -maxdepth 3 -type f -name 'SKILL.md' 2>/dev/null | sort | tr '\n' '\0' | xargs -0 grep -H -m1 '^description:' /dev/null 2>/dev/null)

echo "• KNOWLEDGE + MEMORY — 'Verify-by:' dates not passed (warning only)"
# A volatile fact (port, host, URL) can carry the date it must be re-checked by (R29).
today=$(date +%Y-%m-%d)
while IFS=$US read -r f bytes nsum sum after hasu used sup kw hasv ver; do
  [ "$hasv" = 1 ] || continue
  case "$sum" in "[STALE"*) continue ;; esac
  case "$ver" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
      [[ "$ver" < "$today" ]] && { echo "  EXPIRED 'Verify-by: $ver' (re-check the fact, then move the date or mark it [STALE): $f"; swarn=1; } ;;
    *) echo "  BAD 'Verify-by:' date (want YYYY-MM-DD): $f"; swarn=1 ;;
  esac
done <<<"$DOCS"

echo "• System version — VERSION, CHANGELOG.md and the system-file manifest agree (warning only)"
# Never fails: an install made before versioning existed must still bootstrap (R20, R22).
if [ ! -f VERSION ]; then
  echo "  no VERSION file — run scripts/bump-version.sh 1.0.0 \"<what this install is>\""; swarn=1
else
  ver=$(head -n1 VERSION | tr -d '[:space:]')
  [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "  VERSION is not X.Y.Z: '$ver'"; swarn=1; }
  top=$(grep -m1 '^## ' CHANGELOG.md 2>/dev/null | sed 's/^## *//; s/ .*//')
  [ "$top" = "$ver" ] || { echo "  CHANGELOG.md newest entry is '${top:-none}', VERSION is '$ver' — use scripts/bump-version.sh"; swarn=1; }
  MAN="scripts/.system-manifest"
  if [ -f "$MAN" ]; then
    while read -r h p; do
      [ -n "$p" ] || continue
      real=$p; [ "$p" = MAIN_PROMPT.md ] && [ ! -f "$p" ] && real=../MAIN_PROMPT.md   # prompt kept beside the root (R22)
      if [ ! -f "$real" ]; then echo "  system file in the manifest is gone: $p"; swarn=1
      elif [ "$(shasum -a 256 < "$real" | cut -d' ' -f1)" != "$h" ]; then
        echo "  system file changed since v$ver was stamped: $p — run scripts/bump-version.sh <patch|minor|major> \"<what changed>\""; swarn=1
      fi
    done < "$MAN"
    for p in scripts/*.sh; do
      grep -qF "  $p" "$MAN" || { echo "  script not in the manifest (added since v$ver): $p — run scripts/bump-version.sh"; swarn=1; }
    done
    for p in MAIN_PROMPT.md ../MAIN_PROMPT.md; do
      [ -f "$p" ] || continue
      head -n1 "$p" | grep -qF "(system v$ver)" || { echo "  bootstrap prompt title does not say (system v$ver): $p"; swarn=1; }
      break
    done
  else
    echo "  no $MAN — run scripts/bump-version.sh"; swarn=1
  fi
fi

echo "• SKILLS — every skill has a frontmatter 'description:'"
for f in SKILLS/*/*/SKILL.md; do
  [ -e "$f" ] || continue
  grep -q '^description:' "$f" || { echo "  MISSING description: $f"; fail=1; }
done

echo "• Strays — files the index script can't see"
# Docs must live inside at least one subfolder; a file at KNOWLEDGE/foo.md is orphaned.
for f in KNOWLEDGE/*.md MEMORY/*.md; do
  [ -e "$f" ] || continue
  case "$(basename "$f")" in INDEX.md|INDEX.full.md|SKILL.md) continue ;; esac
  echo "  STRAY (at folder root, invisible to index): $f"; fail=1
done
for d in SKILLS/*/*/; do                            # every skill folder needs a SKILL.md
  [ -d "$d" ] || continue
  [ -e "${d}SKILL.md" ] || { echo "  STRAY (skill folder missing SKILL.md, invisible to index): $d"; fail=1; }
done
for f in SKILLS/*/*.md; do                          # loose files at category level
  [ -e "$f" ] || continue
  echo "  STRAY (loose file at category level, invisible to index): $f"; fail=1
done
# Context root holds only the rule files and the three folders. Anything else
# (scratch logs, scripts) gets committed and loaded by nobody (R5).
for f in *; do
  case "$f" in
    AGENTS.md|CLAUDE.md|MAIN_PROMPT.md|README.md|REFERENCE.md|REQUIREMENTS.md|CHANGELOG.md|VERSION|LICENSE|KNOWLEDGE|MEMORY|SKILLS|POLICIES|scripts) continue ;;
  esac
  echo "  STRAY (unexpected entry at context root): $f"; fail=1
done
# POLICIES/ holds only .md files: bootstrap reads POLICIES/*.md and nothing else, so anything
# else in there (a subfolder, a .txt) would never be read (R34).
if [ -d POLICIES ]; then
  for f in POLICIES/* POLICIES/.[!.]*; do
    [ -e "$f" ] || continue
    case "$f" in POLICIES/*.md) [ -f "$f" ] && continue ;; esac
    echo "  STRAY (POLICIES/ holds only .md files, this is never read): $f"; fail=1
  done
fi

if [ "$content_only" -eq 1 ]; then
  if [ "$fail" -eq 0 ]; then
    echo "OK (content only) — summaries present and one-line, no strays.$([ "$swarn" -ne 0 ] && echo ' Warnings above need a judgment pass.')"
  else
    echo "PROBLEMS found (above). Fix the source files, then re-run ./scripts/rebuild-index.sh"
  fi
  exit $fail
fi

echo "• Freshness — each INDEX.md newer than the content it describes"
for root in KNOWLEDGE MEMORY SKILLS; do
  if [ ! -e "$root/INDEX.md" ]; then
    echo "  MISSING INDEX: $root/INDEX.md — run ./scripts/rebuild-index.sh"; fail=1; continue
  fi
  stale=$(find "$root" -name '*.md' ! -name 'INDEX*.md' -newer "$root/INDEX.md" 2>/dev/null)
  # SLUGS.tsv feeds the slim MEMORY index, so an edit to it also makes that index stale.
  if [ "$root" = MEMORY ] && [ MEMORY/SLUGS.tsv -nt MEMORY/INDEX.md ]; then
    stale=$(printf '%s\n%s' "$stale" MEMORY/SLUGS.tsv | sed '/^$/d')
  fi
  if [ -n "$stale" ]; then
    echo "  STALE INDEX: $root/INDEX.md — changed after the last rebuild:"
    echo "$stale" | sed 's/^/    /'
    echo "    → re-check each file's summary still fits its body, then run ./scripts/rebuild-index.sh"
    fail=1
  fi
done

echo "• Semantic staleness — body changed since summary last confirmed (warning, needs judgment)"
CACHE="scripts/.summary-hashes"
warn=0
if [ -e "$CACHE" ]; then
  # Recompute both hashes for every cached file in one batch, then compare.
  while IFS= read -r cf; do
    [ -n "$cf" ] || continue
    echo "  UNCONFIRMED summary (body changed since it was last confirmed): $cf"
    echo "    → re-read the doc; fix the summary if it no longer fits, or run"
    echo "      ./scripts/confirm-summary.sh '$cf' if it still does (see SKILLS/meta/reconcile-summaries)"
    warn=1
  done < <(
    cut -f3 "$CACHE" | while IFS= read -r cf; do [ -e "$cf" ] && echo "$cf"; done | hash_table \
      | awk -F'\t' -v c="$CACHE" 'BEGIN { while ((getline l < c) > 0) { split(l, a, "\t"); cs[a[3]] = a[1]; cb[a[3]] = a[2] } }
                                 ($3 in cs) && cs[$3] == $1 && cb[$3] != $2 { print $3 }'
  )
else
  echo "  (no cache yet — run ./scripts/rebuild-index.sh once to create it)"
fi

if [ "$fail" -eq 0 ]; then
  if [ "$warn" -eq 0 ] && [ "$swarn" -eq 0 ]; then
    echo "OK — summaries present and one-line, no strays, indexes fresh."
  else
    echo "OK (integrity) — but the warnings above need a judgment pass."
  fi
else
  echo "PROBLEMS found (above). Fix the source files, then re-run ./scripts/rebuild-index.sh"
fi
exit $fail
