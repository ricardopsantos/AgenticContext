#!/usr/bin/env bash
# summary: Searches MEMORY findings (or KNOWLEDGE docs with --knowledge) by keyword: index lines and keywords first, bodies when the index has no hit; skips [ARCHIVE] slugs unless --all; run before investigating a symptom.
# Usage: memory-find.sh [--all|--knowledge] <keyword> [keyword…]   (case-insensitive, AND semantics, max 15 hits)
#   --all       : also search slugs whose MEMORY/SLUGS.tsv description starts with [ARCHIVE]
#   --knowledge : search KNOWLEDGE docs instead (KNOWLEDGE/INDEX.full.md, which carries their keywords; R35)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TREE=MEMORY
ALL=0
case "${1:-}" in --all) ALL=1; shift ;; --knowledge) TREE=KNOWLEDGE; ALL=1; shift ;; esac
FULL="$ROOT/$TREE/INDEX.full.md"
[ $# -ge 1 ] || { echo "usage: memory-find.sh [--all|--knowledge] <keyword> [keyword…]" >&2; exit 2; }
[ -f "$FULL" ] || { echo "missing $FULL — run scripts/rebuild-index.sh" >&2; exit 2; }
MAX=15
# Usage log (R14): one line per search so unused/never-matching queries show up in usage-report.sh.
LOG="${AGENTIC_USAGE_LOG:-$HOME/.agentic-context-usage.log}"
HITS=0; MODE=none
log_use () { mkdir -p "$(dirname "$LOG")" && printf '%s\t%s\t%s\t%s\n' "$(date +%F\ %T)" "$*" "$HITS" "$MODE" >> "$LOG" || true; }

# Archive slugs (R27): bulk history that would crowd the 15-hit cap. One regex of their path prefixes.
ARCH=$(awk -F'\t' '$2 ~ /^\[ARCHIVE\]/{printf "%s%s", s, $1; s="|"}' "$ROOT/MEMORY/SLUGS.tsv" 2>/dev/null || true)
is_arch='^$'                                   # matches nothing useful when there are no archive slugs
[ -n "$ARCH" ] && is_arch="^- \`(${ARCH})/"

all_hits=$(grep '^- `' "$FULL" || true)        # an empty MEMORY has no finding lines
for kw in "$@"; do all_hits=$(printf '%s\n' "$all_hits" | grep -iF -- "$kw" || true); done
if [ "$ALL" -eq 1 ]; then out=$all_hits; hidden=0
else
  out=$(printf '%s\n' "$all_hits" | grep -Ev -- "$is_arch" || true)
  hidden=$(printf '%s\n' "$all_hits" | grep -Ec -- "$is_arch" || true)
fi
archive_note () { [ "${hidden:-0}" -gt 0 ] && echo "(+${hidden} in archive slugs — add --all to include them)"; return 0; }

if [ -n "$out" ]; then
  total=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
  HITS=$total; MODE=index; log_use "$@"
  # Trim each hit to path + first 220 chars of summary + token cost, so a search stays cheap.
  printf '%s\n' "$out" | head -n "$MAX" | awk '{
    tok=""; if (match($0, / \(~[0-9.k]+ tok\)/)) tok=substr($0, RSTART, RLENGTH)
    line=substr($0, 1, 260); if (length($0) > 260) line=line "…" tok; print line }'
  [ "$total" -le "$MAX" ] || echo "(+$((total-MAX)) more — add keywords to narrow)"
  archive_note
  exit 0
fi

# Body fallback (R26): a finding whose summary uses other words is otherwise invisible.
cd "$ROOT"
files=$(grep -rliF --include='*.md' -- "$1" "$TREE" 2>/dev/null | grep -v "^$TREE/[^/]*\$" || true)
shift_kw=("${@:2}")
for kw in "${shift_kw[@]+"${shift_kw[@]}"}"; do
  next=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -qiF -- "$kw" "$f" && next+="$f"$'\n'
  done <<<"$files"
  files=$next
done
files=$(printf '%s\n' "$files" | sed '/^$/d' | LC_ALL=C sort)
if [ "$ALL" -eq 0 ] && [ -n "$ARCH" ]; then
  bhidden=$(printf '%s\n' "$files" | grep -Ec "^MEMORY/(${ARCH})/" || true)
  files=$(printf '%s\n' "$files" | grep -Ev "^MEMORY/(${ARCH})/" || true)
  [ "$bhidden" -gt "$hidden" ] && hidden=$bhidden   # the index hits are (nearly always) the same files
fi
if [ -z "$files" ]; then
  log_use "$@"; [ "$TREE" = MEMORY ] && echo "no findings match: $*" || echo "no KNOWLEDGE docs match: $*"; archive_note; exit 0
fi
total=$(printf '%s\n' "$files" | wc -l | tr -d ' ')
HITS=$total; MODE=body; log_use "$@"
echo "(no index line matches; found in the body. If a hit is the right doc, add this as line 3, under its summary:)"
echo "> keywords: $(printf '%s, ' "$@" | sed 's/, $//')"
printf '%s\n' "$files" | head -n "$MAX" | while IFS= read -r f; do
  sum=$(grep -m1 '^> summary:' "$f" | sed 's/^> summary: //' || true)
  printf -- '- `%s` — [body] %s\n' "${f#"$TREE"/}" "$(printf '%s' "$sum" | cut -c1-200)"
done
[ "$total" -le "$MAX" ] || echo "(+$((total-MAX)) more — add keywords to narrow)"
archive_note
