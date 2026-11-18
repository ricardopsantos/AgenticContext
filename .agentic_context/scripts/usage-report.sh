#!/usr/bin/env bash
# summary: Summarises ~/.agentic-context-usage.log (memory-find.sh searches): totals, top queries, zero-hit queries; --today lists only today's misses for the session debrief; run by hand.
set -euo pipefail
LOG="${AGENTIC_USAGE_LOG:-$HOME/.agentic-context-usage.log}"
[ -s "$LOG" ] || { echo "no usage log yet: $LOG"; exit 0; }
if [ "${1:-}" = "--today" ]; then   # the debrief's review list (R30): misses and body-only hits
  d=$(date +%F)
  echo "-- today's zero-hit searches (write the finding if you learned the answer this session)"
  awk -F'\t' -v d="$d" 'index($1,d)==1 && $3==0{print "  " $2}' "$LOG" | sort -u
  echo "-- today's body-only hits (the finding exists; add a **Keywords:** line so the index matches)"
  awk -F'\t' -v d="$d" 'index($1,d)==1 && $4=="body"{print "  " $2}' "$LOG" | sort -u
  exit 0
fi
echo "searches: $(wc -l < "$LOG")   first: $(head -1 "$LOG" | cut -f1)"
echo "-- top queries"
cut -f2 "$LOG" | sort | uniq -c | sort -rn | head -10
echo "-- zero-hit queries"
awk -F'\t' '$3==0{print $2}' "$LOG" | sort | uniq -c | sort -rn | head -10
