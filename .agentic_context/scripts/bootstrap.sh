#!/usr/bin/env bash
# summary: One-call session bootstrap: pulls the repo, rebuilds and validates the indexes, lists the files to read and open handoffs, then prints the stats; run once at session start.
# Usage: bootstrap.sh [--no-pull]
# Replaces four separate tool rounds (pull, rebuild, validate, stats). Output is
# kept short on purpose: validate prints only its findings, and the files to
# load are listed (read them in one parallel batch), never dumped here.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
rc=0

echo "== SYNC =="
if [ "${1:-}" = "--no-pull" ]; then
  echo "skipped (--no-pull)"
elif top=$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null) && git -C "$top" remote | grep -q .; then
  # --autostash: the derived indexes are usually dirty from the last rebuild.
  if out=$(git -C "$top" pull --rebase --autostash 2>&1); then
    printf '%s\n' "$out" | tail -n 2
  else
    printf '%s\n' "$out" | tail -n 15
    echo "PULL FAILED. Conflict only on INDEX*.md / .summary-hashes: run scripts/rebuild-index.sh, git add those paths, git rebase --continue. Anything else: stop and surface it."
    rc=1
  fi
else
  echo "skipped (not a git clone with a remote)"
fi

echo; echo "== INDEXES =="
if rb=$(./scripts/rebuild-index.sh 2>&1); then
  printf '%s\n' "$rb" | grep -v '^wrote ' || true
  echo "rebuilt"
else
  printf '%s\n' "$rb"; echo "REBUILD FAILED"; rc=1
fi
# Findings (indented lines) and the verdict only; the "•" section titles are noise when all is well.
v=$(./scripts/validate.sh 2>&1); vrc=$?
printf '%s\n' "$v" | grep -v '^• ' || true
[ "$vrc" -eq 0 ] || rc=1

echo; echo "== READ NEXT (one parallel batch) =="
# POLICIES/*.md: extra rules a user keeps beside the framework's own (R34); every file is read, in name order.
for f in AGENTS.md POLICIES/*.md KNOWLEDGE/SKILL.md KNOWLEDGE/INDEX.md MEMORY/SKILL.md MEMORY/INDEX.md SKILLS/SKILL.md SKILLS/INDEX.md; do
  [ -f "$f" ] && echo "$ROOT/$f"
done
grep '\[CORE\]' KNOWLEDGE/INDEX.md 2>/dev/null | sed -n 's/^- `\([^`]*\)`.*/\1/p' | while IFS= read -r f; do echo "$ROOT/KNOWLEDGE/$f  [CORE]"; done

# Open handoffs: unfinished work a previous session wrote down before going cold.
if [ -d MEMORY/handoff ]; then
  open=$(grep -L '^> summary: \[STALE' MEMORY/handoff/*.md 2>/dev/null || true)
  if [ -n "$open" ]; then
    echo; echo "== OPEN HANDOFFS (tell the user; read one only if they resume it) =="
    printf '%s\n' "$open" | while IFS= read -r f; do
      printf '%s — %s\n' "$f" "$(grep -m1 '^> summary:' "$f" | sed 's/^> summary: //' | cut -c1-200)"
    done
  fi
fi

echo; echo "== STATS (paste everything below verbatim to the user) =="
./scripts/stats.sh
exit $rc
