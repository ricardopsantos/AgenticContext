#!/usr/bin/env bash
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
[ "${1:-}" = "--content" ] && content_only=1

check_summary () { # $1 = file
  if ! grep -q '^> summary:' "$1"; then
    echo "  MISSING summary : $1"; fail=1; return
  fi
  if grep -qE '^> summary: *$' "$1"; then
    echo "  EMPTY   summary : $1"; fail=1; return
  fi
  # summary must be exactly one line: the line right after it must be blank
  next=$(awk '/^> summary:/{if (getline nl > 0) print nl; exit}' "$1")
  if [ -n "$next" ]; then
    echo "  MULTILINE summary (line after '> summary:' must be blank): $1"; fail=1
  fi
}

echo "• KNOWLEDGE + MEMORY — every doc has a one-line '> summary:'"
# Walk any depth; index script recurses now.
while IFS= read -r f; do
  case "$(basename "$f")" in INDEX.md|SKILL.md) continue ;; esac
  check_summary "$f"
done < <(find KNOWLEDGE MEMORY -mindepth 2 -type f -name '*.md' 2>/dev/null)

echo "• MEMORY — 'Used in:' lines well-formed (when present)"
while IFS= read -r f; do
  case "$(basename "$f")" in INDEX.md|SKILL.md) continue ;; esac
  grep -q '^\*\*Used in:\*\*' "$f" || continue
  u=$(grep -m1 '^\*\*Used in:\*\*' "$f" | sed 's/^\*\*Used in:\*\* *//')
  if [ -z "$u" ]; then
    echo "  EMPTY 'Used in:' line: $f"; fail=1; continue
  fi
  dups=$(printf '%s\n' "$u" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' | sort | uniq -d)
  if [ -n "$dups" ]; then
    echo "  DUPLICATE domain(s) in 'Used in:' [$(echo $dups | tr '\n' ' ')]: $f"; fail=1
  fi
done < <(find MEMORY -mindepth 2 -type f -name '*.md' 2>/dev/null)

echo "• SKILLS — every skill has a frontmatter 'description:'"
for f in SKILLS/*/*/SKILL.md; do
  [ -e "$f" ] || continue
  grep -q '^description:' "$f" || { echo "  MISSING description: $f"; fail=1; }
done

echo "• Strays — files the index script can't see"
# Docs must live inside at least one subfolder; a file at KNOWLEDGE/foo.md is orphaned.
for f in KNOWLEDGE/*.md MEMORY/*.md; do
  [ -e "$f" ] || continue
  case "$(basename "$f")" in INDEX.md|SKILL.md) continue ;; esac
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

if [ "$content_only" -eq 1 ]; then
  if [ "$fail" -eq 0 ]; then
    echo "OK (content only) — summaries present and one-line, no strays."
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
  stale=$(find "$root" -name '*.md' ! -name 'INDEX.md' -newer "$root/INDEX.md" 2>/dev/null)
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
  while IFS=$'\t' read -r cs cb cf; do
    [ -e "$cf" ] || continue                      # deleted file; next rebuild prunes it
    case "$cf" in
      SKILLS/*) sl=$(grep -m1 '^description:' "$cf" 2>/dev/null || true)
                b=$(grep -v '^description:' "$cf" | shasum -a 256 | cut -d' ' -f1) ;;
      *)        sl=$(grep -m1 '^> summary:' "$cf" 2>/dev/null || true)
                b=$(grep -v '^> summary:' "$cf" | shasum -a 256 | cut -d' ' -f1) ;;
    esac
    s=$(printf '%s' "$sl" | shasum -a 256 | cut -d' ' -f1)
    if [ "$s" = "$cs" ] && [ "$b" != "$cb" ]; then
      echo "  UNCONFIRMED summary (body changed since it was last confirmed): $cf"
      echo "    → re-read the doc; fix the summary if it no longer fits, or run"
      echo "      ./scripts/confirm-summary.sh '$cf' if it still does (see SKILLS/meta/reconcile-summaries)"
      warn=1
    fi
  done < "$CACHE"
else
  echo "  (no cache yet — run ./scripts/rebuild-index.sh once to create it)"
fi

if [ "$fail" -eq 0 ]; then
  if [ "$warn" -eq 0 ]; then
    echo "OK — summaries present and one-line, no strays, indexes fresh."
  else
    echo "OK (integrity) — but unconfirmed summaries above need a judgment pass."
  fi
else
  echo "PROBLEMS found (above). Fix the source files, then re-run ./scripts/rebuild-index.sh"
fi
exit $fail
