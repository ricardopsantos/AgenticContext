#!/usr/bin/env bash
# summary: Checks stats.sh requirements R11-R13 against the live context root; run by hand after editing stats.sh.
set -uo pipefail
cd "$(dirname "$0")"
out=$(./stats.sh); rc=0
chk () { if eval "$2" <<<"$out" >/dev/null; then echo "ok   $1"; else echo "FAIL $1"; rc=1; fi; }
chk "R11 lists KNOWLEDGE/SKILL.md"   "grep -q 'KNOWLEDGE/SKILL.md'"
chk "R11 lists a [CORE] doc"         "grep -q '\[CORE\]'"
chk "R11 total states file count"    "grep -Eq 'TOTAL \([0-9]+ files'"
chk "R12 SKILLS counts > 0 files"    "awk '/== SKILLS/{f=1} f&&/files:/{exit !(\$4>0)}'"
chk "R13 no drift warning on clean tree" "! grep -q '^WARNING'"
exit $rc
