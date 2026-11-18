#!/usr/bin/env bash
# summary: Adds or replaces one row of MEMORY/SLUGS.tsv (a MEMORY folder's one-line description), keeping the file sorted and tab-clean; run when you create a MEMORY/<slug>/ folder.
# Usage: set-slug.sh <slug> "<one-line description>"
set -euo pipefail
cd "$(dirname "$0")/.."
[ $# -eq 2 ] || { echo 'usage: set-slug.sh <slug> "<one-line description>"' >&2; exit 2; }
slug=$1; desc=$2
case "$slug" in
  ""|*/*|.*) echo "slug must be a plain folder name under MEMORY/ (no '/', not empty, no leading '.')" >&2; exit 1 ;;
esac
[ -d "MEMORY/$slug" ] || { echo "no folder MEMORY/$slug — create it first" >&2; exit 1; }
case "$desc" in
  ""|*$'\t'*|*$'\n'*) echo "description must be one non-empty line without tabs" >&2; exit 1 ;;
esac
tsv=MEMORY/SLUGS.tsv; touch "$tsv"
{ awk -F'\t' -v s="$slug" '$1!=s' "$tsv"; printf '%s\t%s\n' "$slug" "$desc"; } \
  | LC_ALL=C sort -t$'\t' -k1,1 > "$tsv.tmp" && mv "$tsv.tmp" "$tsv"
echo "set $slug in $tsv (run scripts/rebuild-index.sh to refresh MEMORY/INDEX.md)"
