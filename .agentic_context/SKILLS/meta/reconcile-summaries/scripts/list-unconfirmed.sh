#!/usr/bin/env bash
# summary: Rebuilds the indexes, runs validate.sh and prints only the paths with UNCONFIRMED summaries (step 1 of reconcile-summaries); prints nothing when none.
set -uo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/../../../.." && pwd)}"   # default: the context root this skill lives in
"$ROOT/scripts/rebuild-index.sh" >/dev/null
"$ROOT/scripts/validate.sh" 2>&1 | sed -n 's/.*UNCONFIRMED summary[^:]*: *//p'
