#!/usr/bin/env bash
# Confirm that a doc's summary still fits its body after a body-only edit.
# Updates that file's entry in scripts/.summary-hashes so validate.sh stops
# flagging it as UNCONFIRMED. Run only AFTER actually re-reading the doc —
# this records a judgment, it doesn't make one.
set -euo pipefail
ORIG_PWD="$PWD"                                      # caller's cwd, before we cd below
cd "$(dirname "$0")/.."
ROOT="$PWD"
CACHE="scripts/.summary-hashes"

[ $# -ge 1 ] || { echo "usage: confirm-summary.sh <file> [<file>...]"; exit 1; }
[ -e "$CACHE" ] || { echo "no cache — run ./scripts/rebuild-index.sh first"; exit 1; }

fail=0
for f in "$@"; do
  case "$f" in
    /*) : ;;                                         # already absolute
    *)  f="$ORIG_PWD/$f" ;;                          # relative → resolve against caller's cwd first
  esac
  f="${f#"$ROOT"/}"                                  # absolute → repo-root relative
  if [ ! -e "$f" ]; then echo "NOT FOUND: $f"; fail=1; continue; fi
  case "$f" in
    SKILLS/*) sl=$(grep -m1 '^description:' "$f" 2>/dev/null || true)
              b=$(grep -v '^description:' "$f" | shasum -a 256 | cut -d' ' -f1) ;;
    *)        sl=$(grep -m1 '^> summary:' "$f" 2>/dev/null || true)
              b=$(grep -v '^> summary:' "$f" | shasum -a 256 | cut -d' ' -f1) ;;
  esac
  if [ -z "$sl" ]; then echo "NO SUMMARY LINE (nothing to confirm): $f"; fail=1; continue; fi
  s=$(printf '%s' "$sl" | shasum -a 256 | cut -d' ' -f1)
  tmp="${CACHE}.tmp"
  awk -F'\t' -v p="$f" '$3!=p' "$CACHE" > "$tmp"
  printf '%s\t%s\t%s\n' "$s" "$b" "$f" >> "$tmp"
  mv "$tmp" "$CACHE"
  echo "confirmed: $f"
done
exit $fail
