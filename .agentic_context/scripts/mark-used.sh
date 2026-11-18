#!/usr/bin/env bash
# summary: Appends a domain to a MEMORY finding's "Used in:" line (creating the line if absent, never duplicating); run when a finding answered a task.
# Usage: mark-used.sh <finding path, as memory-find.sh prints it> <domain>
# Promotion counts distinct domains (>=3), so this one command is the whole
# usage-tracking step: no hand-editing, no malformed lines.
set -euo pipefail
ORIG_PWD=$PWD
cd "$(dirname "$0")/.."
[ $# -eq 2 ] || { echo "usage: mark-used.sh <finding> <domain>" >&2; exit 2; }
f=$1; dom=$2
case "$dom" in ""|*,*|*$'\n'*) echo "domain must be one non-empty word or phrase without commas" >&2; exit 1 ;; esac
for c in "$f" "MEMORY/$f" "$ORIG_PWD/$f"; do [ -f "$c" ] && { f=$c; break; }; done
[ -f "$f" ] || { echo "no such finding: $1" >&2; exit 1; }
case "$(cd "$(dirname "$f")" && pwd)/" in "$PWD/MEMORY/"?*) ;; *) echo "not a MEMORY finding: $f" >&2; exit 1 ;; esac

if grep -q '^\*\*Used in:\*\*' "$f"; then
  cur=$(grep -m1 '^\*\*Used in:\*\*' "$f" | sed 's/^\*\*Used in:\*\* *//')
  if printf '%s\n' "$cur" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -qixF -- "$dom"; then
    echo "already used in '$dom': $f"; exit 0
  fi
  awk -v d="$dom" '!done && /^\*\*Used in:\*\*/{sub(/[ ,]*$/, ""); print ($0 ~ /\*\*$/ ? $0 " " d : $0 ", " d); done=1; next} {print}' "$f" > "$f.tmp"
else
  # After the last header field present (Context, else Discovered), else after the summary line.
  anchor=$(grep -n -E '^\*\*(Context|Discovered):\*\*' "$f" | tail -1 | cut -d: -f1 || true)
  pre=""
  if [ -z "$anchor" ]; then                    # the line after the summary must stay blank (validate: MULTILINE)
    anchor=$(grep -n -m1 '^> summary:' "$f" | cut -d: -f1 || true); pre=1
  fi
  [ -n "$anchor" ] || { echo "no summary or header field to anchor on: $f" >&2; exit 1; }
  awk -v n="$anchor" -v d="$dom" -v pre="$pre" '{print} NR==n{if (pre) print ""; print "**Used in:** " d}' "$f" > "$f.tmp"
fi
cat "$f.tmp" > "$f" && rm -f "$f.tmp"
echo "used in '$dom': $f (run scripts/rebuild-index.sh)"
