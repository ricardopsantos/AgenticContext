#!/usr/bin/env bash
# summary: Tests every script requirement except the stats ones (R1-R10, R14-R32: index, search, slugs, validate, versioning, bootstrap, mark-used) against throwaway context trees; run by hand.
# Tests REQUIREMENTS.md R1-R4,R7 for rebuild-index.sh and R5,R6 for validate.sh.
# Builds a throwaway context tree in $TMPDIR so the real KNOWLEDGE/MEMORY/SKILLS
# are never touched, runs the real script against it, and asserts on the output.
set -uo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
pass=0; fail=0

check () { # check <description> <condition-result>
  if [ "$2" = "0" ]; then pass=$((pass+1)); printf '  ok   %s\n' "$1"
  else fail=$((fail+1)); printf '  FAIL %s\n' "$1"; fi
}

work=$(mktemp -d)
trap '[ -n "${KEEP:-}" ] || rm -rf "$work"; [ -z "${KEEP:-}" ] || echo "$work"' EXIT

mkdir -p "$work"/{KNOWLEDGE,MEMORY/slug,SKILLS}
printf 'slug\ta test slug\n' > "$work/MEMORY/SLUGS.tsv"
cp "$SCRIPT_DIR/rebuild-index.sh" "$work/scripts_rebuild.sh" 2>/dev/null || {
  echo "cannot find rebuild-index.sh next to this test"; exit 2; }
mkdir -p "$work/scripts"; mv "$work/scripts_rebuild.sh" "$work/scripts/rebuild-index.sh"
cp "$SCRIPT_DIR/lib.sh" "$work/scripts/"       # sourced by rebuild-index.sh and validate.sh
chmod +x "$work/scripts/rebuild-index.sh"

# Three domains each, so the >=3 auto-tag threshold is met in every case and the
# prefix is the only variable under test.
finding () { # finding <file> <summary>
  printf '# T\n> summary: %s\n\n**Discovered:** 2026-01-01\n**Used in:** a, b, c\n' \
    "$2" > "$work/MEMORY/slug/$1"
}
finding stale.md    '[STALE — superseded by other.md] a superseded plan'
finding promote.md  '[PROMOTE? hand] a hand-flagged finding'
finding reviewed.md '[REVIEWED 2026-08-07 — not for promotion, settled] a rejected finding'
finding plain.md    'an ordinary finding with no prefix'

( cd "$work" && ./scripts/rebuild-index.sh ) >/dev/null 2>&1
idx="$work/MEMORY/INDEX.full.md"
[ -f "$idx" ] || { echo "no INDEX.full.md produced"; exit 2; }

# R1 — the stale entry sits below the superseded heading, not in the active list.
head_line=$(grep -n '^## superseded/' "$idx" | cut -d: -f1)
stale_line=$(grep -n 'slug/stale\.md' "$idx" | cut -d: -f1)
[ -n "$head_line" ] && [ -n "$stale_line" ] && [ "$stale_line" -gt "$head_line" ]
check "R1 [STALE — …] routed to the superseded tail section" $?

# R2 — none of the three prefixed entries may carry the auto tag.
for p in stale promote reviewed; do
  ! grep "slug/${p}\.md" "$idx" | grep -q 'PROMOTE? auto'
  check "R2 [${p}] not auto-tagged despite 3 used-in domains" $?
done

# R3 — guards the actual regression: a pattern anchored on "]" would drop both
# rules for every real finding, which all carry an explanation in the brackets.
grep -q '"\[STALE\]"\*' "$SCRIPT_DIR/rebuild-index.sh"
check "R3 no closing-bracket-anchored [STALE] pattern remains" $((1-$?))

# R4 — the unprefixed entry still gets tagged, so R2 did not over-suppress.
grep 'slug/plain\.md' "$idx" | grep -q 'PROMOTE? auto — used in 3 domains'
check "R4 unprefixed finding at 3 domains is auto-tagged" $?

# R5 — validate.sh flags an unexpected entry at the context root, and only that.
cp "$SCRIPT_DIR/validate.sh" "$work/scripts/validate.sh"; chmod +x "$work/scripts/validate.sh"
touch "$work"/{AGENTS.md,CLAUDE.md,README.md} "$work/.DS_Store"
out=$( cd "$work" && ./scripts/validate.sh --content 2>&1 )
! printf '%s' "$out" | grep -q 'context root'
check "R5 clean root (rule files + dotfile) not flagged" $?
touch "$work/tmp_sweep.log"
out=$( cd "$work" && ./scripts/validate.sh --content 2>&1 ); rc=$?
printf '%s' "$out" | grep -q 'STRAY (unexpected entry at context root): tmp_sweep.log' && [ "$rc" -ne 0 ]
check "R5 tmp_sweep.log at root flagged as STRAY, non-zero exit" $?

# R6/R7 — supersede links: validate.sh warns without failing; the index shows the arrow.
rm -f "$work/tmp_sweep.log"
mkdir -p "$work/MEMORY/sup"
sup () { printf '# T\n> summary: %s\n\n**Discovered:** 2026-01-01\n%s\n' "$2" "$3" > "$work/MEMORY/sup/$1"; }
sup new.md  'the replacement' '**Corrects:** old.md'
sup old.md  '[STALE — superseded by new.md] the old one' '**Superseded-by:** new.md'
sup nolink.md '[STALE — superseded by new.md] no field' ''
sup gone.md '[STALE — superseded by x.md] missing target' '**Superseded-by:** missing.md'
sup noback.md '[STALE — superseded by plain.md] no back-link' '**Superseded-by:** slug/plain.md'
sup fixed.md '[STALE — fixed] closed out, not superseded' ''
( cd "$work" && ./scripts/rebuild-index.sh ) >/dev/null 2>&1
out=$( cd "$work" && ./scripts/validate.sh --content 2>&1 ); rc=$?
printf '%s' "$out" | grep -q "NO 'Superseded-by:'.*nolink.md"
check "R6 superseded finding without Superseded-by: warned" $?
printf '%s' "$out" | grep -q "target missing (missing.md).*gone.md"
check "R6 missing Superseded-by target warned" $?
printf '%s' "$out" | grep -q "lacks back-link.*plain.md"
check "R6 target without Corrects: back-link warned" $?
! printf '%s' "$out" | grep -qE "sup/(old|new|fixed)\.md"
check "R6 complete pair and plain [STALE — fixed] not warned" $?
[ "$rc" -eq 0 ]
check "R6 warnings do not change the exit code" $?
grep 'sup/old\.md' "$work/MEMORY/INDEX.full.md" | grep -q -- '-> new.md'
check "R7 stale tail entry shows -> replacement" $?

# R8/R9/R10 — slim MEMORY/INDEX.md is a slug map, not a catalogue; memory-find searches the full one.
slim="$work/MEMORY/INDEX.md"
! grep -q 'the replacement' "$slim" && grep -q 'slug/` — [0-9]* findings — a test slug' "$slim"
check "R8 slim INDEX.md lists slugs with counts, not finding summaries" $?
grep -q 'a hand-flagged finding' "$slim"
check "R8 slim INDEX.md keeps promotion candidates" $?
grep -q "no row for 'sup'" <( cd "$work" && ./scripts/rebuild-index.sh 2>&1 )
check "R9 slug folder without SLUGS.tsv row is warned" $?
cp "$SCRIPT_DIR/memory-find.sh" "$work/scripts/"; chmod +x "$work/scripts/memory-find.sh"
out=$( cd "$work" && ./scripts/memory-find.sh ORDINARY finding )
printf '%s' "$out" | grep -q 'slug/plain\.md' && ! printf '%s' "$out" | grep -q 'stale\.md'
check "R10 memory-find is case-insensitive and ANDs keywords" $?

# R14 — each search (hit or miss) appends a tab-separated log line.
ulog="$work/usage.log"
( cd "$work" && AGENTIC_USAGE_LOG="$ulog" ./scripts/memory-find.sh ORDINARY finding >/dev/null; AGENTIC_USAGE_LOG="$ulog" ./scripts/memory-find.sh zzznomatch >/dev/null )
[ "$(wc -l < "$ulog")" = 2 ] && awk -F'\t' 'NR==1{ok=($2=="ORDINARY finding" && $3>0)} NR==2{ok=ok&&($2=="zzznomatch" && $3==0)} END{exit !ok}' "$ulog"
check "R14 memory-find logs hits and zero-hit searches" $?

# R15 — set-slug.sh upserts one tab row, keeps the file sorted, refuses a bad slug or description.
cp "$SCRIPT_DIR/set-slug.sh" "$work/scripts/"; chmod +x "$work/scripts/set-slug.sh"
mkdir -p "$work/MEMORY/aaa" "$work/MEMORY/zzz"
( cd "$work" && ./scripts/set-slug.sh zzz "first" >/dev/null && ./scripts/set-slug.sh aaa "alpha" >/dev/null && ./scripts/set-slug.sh zzz "second" >/dev/null )
[ "$(grep -c '^zzz	' "$work/MEMORY/SLUGS.tsv")" = 1 ] && grep -q '^zzz	second$' "$work/MEMORY/SLUGS.tsv" \
  && [ "$(grep -n '^aaa	' "$work/MEMORY/SLUGS.tsv" | cut -d: -f1)" -lt "$(grep -n '^zzz	' "$work/MEMORY/SLUGS.tsv" | cut -d: -f1)" ]
check "R15 set-slug upserts one row and keeps the file sorted" $?
( cd "$work" && ! ./scripts/set-slug.sh nofolder "x" 2>/dev/null && ! ./scripts/set-slug.sh aaa "" 2>/dev/null && ! ./scripts/set-slug.sh aaa "a	b" 2>/dev/null )
check "R15 set-slug refuses a missing folder, an empty or tab-bearing description" $?

# R16 — validate.sh warns (never fails) on a folder with no row and on a row with no folder.
cp "$SCRIPT_DIR/validate.sh" "$work/scripts/"; chmod +x "$work/scripts/validate.sh"
mkdir -p "$work/MEMORY/norow"; printf 'ghost\tno such folder\n' >> "$work/MEMORY/SLUGS.tsv"
vout=$( cd "$work" && ./scripts/validate.sh --content 2>&1 )
printf '%s' "$vout" | grep -q 'no SLUGS.tsv row for MEMORY/norow/' && printf '%s' "$vout" | grep -q "row 'ghost' has no MEMORY/ghost/ folder"
check "R16 validate warns on a missing and on an orphan SLUGS.tsv row" $?

# R17 — set-slug.sh refuses an empty slug and one that is a path, not a folder name.
( cd "$work" && ! ./scripts/set-slug.sh "" "x" 2>/dev/null && ! ./scripts/set-slug.sh ../KNOWLEDGE "x" 2>/dev/null && ! ./scripts/set-slug.sh aaa/b "x" 2>/dev/null )
check "R17 set-slug refuses an empty slug and a slug with '/'" $?

# R19 — editing SLUGS.tsv after a rebuild makes MEMORY/INDEX.md stale.
( cd "$work" && ./scripts/rebuild-index.sh >/dev/null 2>&1; touch -d '+2 seconds' MEMORY/SLUGS.tsv )
printf '%s' "$( cd "$work" && ./scripts/validate.sh 2>&1 )" | grep -A2 'STALE INDEX: MEMORY/INDEX.md' | grep -q 'MEMORY/SLUGS.tsv'
check "R19 a SLUGS.tsv newer than MEMORY/INDEX.md is reported stale" $?

# R18 — an empty MEMORY (no slug folders) gives a clean slim index and a clean search.
empty=$(mktemp -d); mkdir -p "$empty"/{KNOWLEDGE,MEMORY,SKILLS,scripts}
cp "$SCRIPT_DIR/rebuild-index.sh" "$SCRIPT_DIR/memory-find.sh" "$SCRIPT_DIR/lib.sh" "$empty/scripts/"; chmod +x "$empty/scripts/"*.sh
( cd "$empty" && ./scripts/rebuild-index.sh >/dev/null 2>&1 ) \
  && ! grep -q '`\*/`' "$empty/MEMORY/INDEX.md" && grep -q 'no slug folders yet' "$empty/MEMORY/INDEX.md"
check "R18 empty MEMORY: slim index has no junk glob row" $?
mout=$( cd "$empty" && AGENTIC_USAGE_LOG="$empty/u.log" ./scripts/memory-find.sh anything ); mrc=$?
[ "$mrc" = 0 ] && printf '%s' "$mout" | grep -q 'no findings match'
check "R18 empty MEMORY: memory-find exits 0 with 'no findings match'" $?
rm -rf "$empty"

# ---------------------------------------------------------------------------
# R20-R32 run in a second, clean tree with every script installed.
w2=$(mktemp -d); mkdir -p "$w2"/{KNOWLEDGE/fam,MEMORY/slug,MEMORY/old,SKILLS/cat/sk,scripts}
cp "$SCRIPT_DIR"/*.sh "$w2/scripts/"; chmod +x "$w2/scripts/"*.sh
touch "$w2"/{AGENTS.md,CLAUDE.md,README.md}; printf '# Session bootstrap\n\nbody\n' > "$w2/MAIN_PROMPT.md"
printf '# R\n\n**R1.** x\n' > "$w2/REQUIREMENTS.md"
for d in KNOWLEDGE MEMORY SKILLS; do printf -- '---\nname: x\ndescription: skeleton\n---\n' > "$w2/$d/SKILL.md"; done
printf -- '---\nname: sk\ndescription: a skill\n---\nbody\n' > "$w2/SKILLS/cat/sk/SKILL.md"
printf 'slug\tlive findings\nold\t[ARCHIVE] closed history\n' > "$w2/MEMORY/SLUGS.tsv"
doc () { printf '# T\n> summary: %s\n\n%s\n' "$2" "${3:-body}" > "$w2/$1"; }
doc KNOWLEDGE/fam/Doc.md 'a short routing line'
doc MEMORY/slug/20990101_000000_plain.md 'the kettle trips the breaker' 'Seen when the descaler runs.'
doc MEMORY/slug/20990101_000001_kw.md 'gateway returns 502 after restart' '**Keywords:** bad gateway, upstream'
doc MEMORY/old/20200101_000000_arch.md 'kettle card closed long ago'
run2 () { ( cd "$w2" && "$@" ); }
val2 () { run2 ./scripts/validate.sh 2>&1; }

# R20/R21 — bump-version writes VERSION, a newest-first CHANGELOG entry, the prompt title and the manifest.
run2 ./scripts/bump-version.sh 1.0.0 "first version" >/dev/null 2>&1
[ "$(cat "$w2/VERSION")" = "1.0.0" ] && grep -q '^## 1.0.0 — ' "$w2/CHANGELOG.md" && grep -q '^- first version$' "$w2/CHANGELOG.md" \
  && grep -q '  scripts/validate.sh$' "$w2/scripts/.system-manifest" && grep -q '  MAIN_PROMPT.md$' "$w2/scripts/.system-manifest"
check "R21 bump writes VERSION, CHANGELOG entry and the manifest" $?
[ "$(head -n1 "$w2/MAIN_PROMPT.md")" = "# Session bootstrap (system v1.0.0)" ]
check "R21 bump stamps the bootstrap prompt title" $?
run2 ./scripts/bump-version.sh patch "second" >/dev/null 2>&1
[ "$(cat "$w2/VERSION")" = "1.0.1" ] && [ "$(grep -m1 '^## ' "$w2/CHANGELOG.md" | cut -d' ' -f2)" = "1.0.1" ] \
  && [ "$(grep -c '^## ' "$w2/CHANGELOG.md")" = 2 ] && [ "$(head -n1 "$w2/MAIN_PROMPT.md")" = "# Session bootstrap (system v1.0.1)" ]
check "R21 patch bump: 1.0.1 on top, title restamped not appended" $?
( run2 ./scripts/bump-version.sh patch "" 2>/dev/null; [ $? -ne 0 ] ) && ( run2 ./scripts/bump-version.sh banana "x" 2>/dev/null; [ $? -ne 0 ] ) && [ "$(cat "$w2/VERSION")" = "1.0.1" ]
check "R21 bump refuses an empty changelog line and a bad version" $?

# R21 — --restamp refreshes title and manifest only.
cp "$w2/VERSION" "$work/v.keep"; cp "$w2/CHANGELOG.md" "$work/c.keep"; sed -i 's/^# Session bootstrap.*/# Session bootstrap/' "$w2/MAIN_PROMPT.md"; echo '# edit' >> "$w2/scripts/set-slug.sh"
run2 ./scripts/bump-version.sh --restamp >/dev/null 2>&1
cmp -s "$w2/VERSION" "$work/v.keep" && cmp -s "$w2/CHANGELOG.md" "$work/c.keep" && [ "$(head -n1 "$w2/MAIN_PROMPT.md")" = "# Session bootstrap (system v1.0.1)" ] \
  && grep "  scripts/set-slug.sh$" "$w2/scripts/.system-manifest" | grep -q "^$(shasum -a 256 < "$w2/scripts/set-slug.sh" | cut -d' ' -f1)"
check "R21 --restamp keeps VERSION/CHANGELOG, refreshes title and manifest" $?
mv "$w2/VERSION" "$work/v.tmp"; ( run2 ./scripts/bump-version.sh --restamp 2>/dev/null; [ $? -ne 0 ] ); check "R21 --restamp refuses without a VERSION" $?; mv "$work/v.tmp" "$w2/VERSION"

# R23 — the version is stamped into every derived index header and printed by stats.sh.
run2 ./scripts/rebuild-index.sh >/dev/null 2>&1
n=0; for i in KNOWLEDGE/INDEX.md MEMORY/INDEX.md MEMORY/INDEX.full.md SKILLS/INDEX.md; do grep -q 'System v1\.0\.1\.' "$w2/$i" && n=$((n+1)); done
[ "$n" = 4 ]
check "R23 all four index headers carry 'System v1.0.1.'" $?
out=$(run2 ./scripts/stats.sh 2>/dev/null); printf '%s' "$out" | grep -q 'version: 1\.0\.1'
check "R23 stats.sh prints the system version" $?

# R22 — the manifest names the prompt "MAIN_PROMPT.md" wherever it sits, so an install that keeps it inside the root validates clean too.
grep -q '  MAIN_PROMPT.md$' "$w2/scripts/.system-manifest" && ! grep -q '\.\./' "$w2/scripts/.system-manifest"
check "R22 manifest names the prompt MAIN_PROMPT.md, never a ../ path" $?
mkdir -p "$w2/../inst-$$" && w3="$w2/../inst-$$"
cp -R "$w2/." "$w3/" && mkdir -p "$w3/ctx" && mv "$w3"/{KNOWLEDGE,MEMORY,SKILLS,scripts,AGENTS.md,CLAUDE.md,README.md,REQUIREMENTS.md,VERSION,CHANGELOG.md} "$w3/ctx/" 2>/dev/null
out=$( cd "$w3/ctx" && ./scripts/validate.sh 2>&1 ); rm -rf "$w3"
! printf '%s' "$out" | grep -qE 'manifest is gone|changed since v|prompt title'
check "R22 prompt kept beside the root (../MAIN_PROMPT.md) validates clean" $?

# R20/R22 — validate: clean after a bump; warns (exit unchanged) on drift, a new script, a VERSION/CHANGELOG mismatch.
out=$(val2); rc=$?
[ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -qE 'changed since v|not in the manifest|no VERSION|newest entry|prompt title'
check "R22 freshly bumped tree: no version warnings" $?
echo '# drift' >> "$w2/scripts/set-slug.sh"; printf '#!/usr/bin/env bash\n# summary: x\n' > "$w2/scripts/extra.sh"
out=$(val2); rc=$?
printf '%s' "$out" | grep -q 'system file changed since v1.0.1 was stamped: scripts/set-slug.sh' \
  && printf '%s' "$out" | grep -q 'script not in the manifest (added since v1.0.1): scripts/extra.sh' && [ "$rc" -eq 0 ]
check "R22 edited and added system files warned, exit code unchanged" $?
run2 ./scripts/bump-version.sh minor "third" >/dev/null 2>&1; run2 ./scripts/rebuild-index.sh >/dev/null 2>&1
out=$(val2); ! printf '%s' "$out" | grep -qE 'changed since v|not in the manifest'
check "R22 a bump clears the drift warnings" $?
echo "9.9.9" > "$w2/VERSION"
out=$(val2); printf '%s' "$out" | grep -q "CHANGELOG.md newest entry is '1.1.0', VERSION is '9.9.9'"
check "R20 VERSION that disagrees with CHANGELOG.md is warned" $?
echo "1.1.0" > "$w2/VERSION"

# R24 — bootstrap.sh: one call, lists what to read and the open handoffs, stats last.
mkdir -p "$w2/MEMORY/handoff"; run2 ./scripts/set-slug.sh handoff "unfinished work" >/dev/null
doc MEMORY/handoff/20990101_000000_open.md 'migration half done'
doc MEMORY/handoff/20990101_000001_done.md '[STALE — done] finished one'
out=$(run2 ./scripts/bootstrap.sh --no-pull 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "^$w2/KNOWLEDGE/INDEX.md$" && printf '%s' "$out" | grep -q '^== STATS' \
  && [ "$(printf '%s\n' "$out" | grep -n '^== STATS' | cut -d: -f1)" -gt "$(printf '%s\n' "$out" | grep -n '^== READ NEXT' | cut -d: -f1)" ]
check "R24 bootstrap rebuilds, validates, lists files to read, stats last" $?
printf '%s' "$out" | grep -q 'open.md — migration half done' && ! printf '%s' "$out" | grep -q 'done.md'
check "R24 bootstrap lists open handoffs, not [STALE ones" $?
rm "$w2/MEMORY/slug/20990101_000001_kw.md"; printf '# T\nno summary here\n' > "$w2/MEMORY/slug/20990101_000009_bad.md"
run2 ./scripts/bootstrap.sh --no-pull >/dev/null 2>&1; [ $? -ne 0 ]
check "R24 bootstrap exits non-zero when validate fails" $?
rm "$w2/MEMORY/slug/20990101_000009_bad.md"
doc MEMORY/slug/20990101_000001_kw.md 'gateway returns 502 after restart' '**Keywords:** bad gateway, upstream'

# R25 — summary caps warn, never fail; MEMORY findings dated before the rule are only counted.
long=$(printf 'x%.0s' $(seq 1 320))
doc KNOWLEDGE/fam/Long.md "$long"; doc MEMORY/slug/20990102_000000_long.md "$long"; doc MEMORY/old/20200102_000000_long.md "$long"
printf -- '---\nname: sk\ndescription: %s\n---\n' "$long" > "$w2/SKILLS/cat/sk/SKILL.md"
run2 ./scripts/rebuild-index.sh >/dev/null 2>&1; out=$(val2); rc=$?
printf '%s' "$out" | grep -q 'LONG summary (320 chars, max 200.*KNOWLEDGE/fam/Long.md' && printf '%s' "$out" | grep -q 'LONG description (320 chars, max 300): SKILLS/cat/sk/SKILL.md' \
  && printf '%s' "$out" | grep -q 'LONG summary (320 chars, max 300): MEMORY/slug/20990102_000000_long.md' && [ "$rc" -eq 0 ]
check "R25 over-long KNOWLEDGE, skill and new MEMORY summaries warned, exit 0" $?
! printf '%s' "$out" | grep -q 'MEMORY/old/20200102' && printf '%s' "$out" | grep -q '(1 MEMORY findings dated before'
check "R25 MEMORY finding dated before the rule is counted, not listed" $?
rm "$w2/KNOWLEDGE/fam/Long.md" "$w2"/MEMORY/*/*_long.md; printf -- '---\nname: sk\ndescription: a skill\n---\nbody\n' > "$w2/SKILLS/cat/sk/SKILL.md"
run2 ./scripts/rebuild-index.sh >/dev/null 2>&1

# R34 — POLICIES/: every .md is listed after AGENTS.md; only .md files may sit in it.
mkdir -p "$w2/POLICIES"; printf '# B\nrule b\n' > "$w2/POLICIES/b.md"; printf '# A\nrule a\n' > "$w2/POLICIES/a.md"
out=$(run2 ./scripts/bootstrap.sh --no-pull 2>&1)
[ "$(printf '%s\n' "$out" | grep -n 'POLICIES/' | cut -d: -f1 | tr '\n' ' ')" != "" ] && printf '%s' "$out" | grep -A3 'READ NEXT' | grep -q 'POLICIES/a.md' \
  && printf '%s' "$out" | awk '/POLICIES\/a.md/{a=NR}/POLICIES\/b.md/{b=NR}/KNOWLEDGE\/SKILL.md/{k=NR}END{exit !(a&&b&&a<b&&b<k)}'
check "R34 bootstrap lists every POLICIES/*.md in name order before KNOWLEDGE" $?
out=$(val2); rc=$?; printf '%s' "$out" | grep -q 'STRAY.*POLICIES' && rc2=1 || rc2=0
[ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ]
check "R34 validate accepts POLICIES/ at the root and its .md files" $?
printf 'x' > "$w2/POLICIES/notes.txt"; out=$(val2); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'STRAY (POLICIES/ holds only .md files.*POLICIES/notes.txt'
check "R34 validate flags a non-.md file inside POLICIES/ and exits non-zero" $?
rm -rf "$w2/POLICIES"
out=$(run2 ./scripts/bootstrap.sh --no-pull 2>&1); printf '%s' "$out" | grep -q 'READ NEXT' && ! printf '%s' "$out" | grep -q 'POLICIES/\*'
check "R34 a root without POLICIES/ bootstraps cleanly" $?

# R26/R27/R28 — search: body fallback, archive slugs hidden by default, Keywords in the index.
ulog2=$(mktemp)                                # outside the tree: a log at the root is a STRAY (R5)
mf () { ( cd "$w2" && AGENTIC_USAGE_LOG="$ulog2" ./scripts/memory-find.sh "$@" ); }
out=$(mf DESCALER)
printf '%s' "$out" | grep -q 'slug/20990101_000000_plain.md` — \[body\] the kettle trips' && [ "$(tail -n1 "$ulog2" | cut -f3,4)" = "1	body" ]
check "R26 word only in the body is found by the fallback and logged as body" $?
out=$(mf kettle)
printf '%s' "$out" | grep -q 'plain.md' && ! printf '%s' "$out" | grep -q 'arch.md' && printf '%s' "$out" | grep -q '(+1 in archive slugs'
check "R27 [ARCHIVE] slug hidden by default, with a count note" $?
out=$(mf --all kettle); printf '%s' "$out" | grep -q 'old/20200101_000000_arch.md'
check "R27 --all includes the archive slug" $?
out=$(mf closed long)
printf '%s' "$out" | grep -q 'no findings match' && printf '%s' "$out" | grep -q '(+1 in archive slugs'
check "R27 a hit only in the archive says so instead of a bare miss" $?
out=$(mf UPSTREAM)
printf '%s' "$out" | grep -q 'kw.md` — gateway returns 502 after restart \[kw: bad gateway, upstream\]' && [ "$(tail -n1 "$ulog2" | cut -f4)" = "index" ]
check "R28 a Keywords: term matches on the index line" $?

# R29 — Verify-by: past date warned, future silent, malformed warned, [STALE skipped; never fails.
doc KNOWLEDGE/fam/Past.md 'port table' '**Verify-by:** 2000-01-01'
doc KNOWLEDGE/fam/Future.md 'host table' '**Verify-by:** 2999-01-01'
doc MEMORY/slug/20990103_000000_bad.md 'url note' '**Verify-by:** soon'
doc MEMORY/slug/20990103_000001_st.md '[STALE — fixed] gone' '**Verify-by:** 2000-01-01'
run2 ./scripts/rebuild-index.sh >/dev/null 2>&1; out=$(val2); rc=$?
printf '%s' "$out" | grep -q "EXPIRED 'Verify-by: 2000-01-01'.*KNOWLEDGE/fam/Past.md" && printf '%s' "$out" | grep -q "BAD 'Verify-by:' date.*_bad.md" \
  && ! printf '%s' "$out" | grep -qE 'Verify-by.*(Future|_st)\.md' && [ "$rc" -eq 0 ]
check "R29 Verify-by: expired and malformed warned, future and [STALE silent, exit 0" $?
rm "$w2/KNOWLEDGE/fam/Past.md" "$w2/KNOWLEDGE/fam/Future.md" "$w2"/MEMORY/slug/20990103_*.md

# R30 — usage-report --today lists today's misses and body-only hits.
mf zzznothing >/dev/null
out=$( cd "$w2" && AGENTIC_USAGE_LOG="$ulog2" ./scripts/usage-report.sh --today )
printf '%s' "$out" | grep -q '^  zzznothing$' && printf '%s' "$out" | grep -q '^  DESCALER$'
check "R30 usage-report --today lists zero-hit and body-only searches" $?

# R31 — the one-pass scan still catches every summary defect and body-only drift.
run2 ./scripts/rebuild-index.sh >/dev/null 2>&1
echo 'a new paragraph' >> "$w2/KNOWLEDGE/fam/Doc.md"; run2 ./scripts/rebuild-index.sh >/dev/null 2>&1
out=$(val2); printf '%s' "$out" | grep -q 'UNCONFIRMED summary (body changed since it was last confirmed): KNOWLEDGE/fam/Doc.md'
check "R31 body-only edit is flagged UNCONFIRMED" $?
run2 ./scripts/confirm-summary.sh KNOWLEDGE/fam/Doc.md >/dev/null 2>&1; out=$(val2); ! printf '%s' "$out" | grep -q 'UNCONFIRMED'
check "R31 confirm-summary.sh clears it (same hash definitions)" $?
printf '# T\nnothing\n' > "$w2/MEMORY/slug/20990104_a.md"; printf '# T\n> summary:   \n\nb\n' > "$w2/MEMORY/slug/20990104_b.md"
printf '# T\n> summary: one\nspills over\n' > "$w2/MEMORY/slug/20990104_c.md"; : > "$w2/MEMORY/slug/20990104_d.md"
out=$(run2 ./scripts/validate.sh --content 2>&1); rc=$?
printf '%s' "$out" | grep -q 'MISSING summary : MEMORY/slug/20990104_a.md' && printf '%s' "$out" | grep -q 'EMPTY   summary : MEMORY/slug/20990104_b.md' \
  && printf '%s' "$out" | grep -q 'MULTILINE summary.*20990104_c.md' && printf '%s' "$out" | grep -q 'MISSING summary : MEMORY/slug/20990104_d.md' && [ "$rc" -ne 0 ]
check "R31 missing, empty, multi-line summary and an empty file all fail" $?
rm "$w2"/MEMORY/slug/20990104_*.md

# R33 — a missing lib.sh is named, not a bare "No such file".
mv "$w2/scripts/lib.sh" "$work/lib.keep"
out=$(run2 ./scripts/rebuild-index.sh 2>&1); rc1=$?; out2=$(run2 ./scripts/validate.sh 2>&1); rc2=$?
mv "$work/lib.keep" "$w2/scripts/lib.sh"
[ "$rc1" = 2 ] && [ "$rc2" = 2 ] && printf '%s' "$out" | grep -q 'scripts/lib.sh is missing' && printf '%s' "$out2" | grep -q 'scripts/lib.sh is missing'
check "R33 missing lib.sh: exit 2 and a message naming it, in rebuild and validate" $?

# R32 — mark-used.sh creates the line, appends without duplicating, refuses a non-finding.
run2 ./scripts/mark-used.sh slug/20990101_000000_plain.md homelab >/dev/null
run2 ./scripts/mark-used.sh MEMORY/slug/20990101_000000_plain.md swift >/dev/null
run2 ./scripts/mark-used.sh slug/20990101_000000_plain.md HomeLab >/dev/null
[ "$(grep -c '^\*\*Used in:\*\*' "$w2/MEMORY/slug/20990101_000000_plain.md")" = 1 ] && grep -q '^\*\*Used in:\*\* homelab, swift$' "$w2/MEMORY/slug/20990101_000000_plain.md" \
  && ! run2 ./scripts/validate.sh --content 2>&1 | grep -q 'MULTILINE'
check "R32 mark-used creates the line, appends, ignores a duplicate" $?
( run2 ./scripts/mark-used.sh KNOWLEDGE/fam/Doc.md x 2>/dev/null; [ $? -ne 0 ] ) && ( run2 ./scripts/mark-used.sh slug/20990101_000000_plain.md "a,b" 2>/dev/null; [ $? -ne 0 ] )
check "R32 mark-used refuses a non-MEMORY file and a domain with a comma" $?
run2 ./scripts/mark-used.sh slug/20990101_000000_plain.md kmp >/dev/null; run2 ./scripts/rebuild-index.sh >/dev/null 2>&1
grep 'plain.md' "$w2/MEMORY/INDEX.full.md" | grep -q 'PROMOTE? auto — used in 3 domains'
check "R32 three marked domains reach the auto-promotion tag (R4)" $?
# R35 — a "> keywords:" line under the summary: searchable, KNOWLEDGE keywords stay out of the loaded index.
mkdir -p "$w2/KNOWLEDGE/fam"
printf '# K\n> summary: how the widget deploy works\n> keywords: zebracode, moved tag\n\nbody\n' > "$w2/KNOWLEDGE/fam/Kw.md"
printf '# F\n> summary: a plain finding\n> keywords: quokkaword\n\nbody text flamingo\n' > "$w2/MEMORY/slug/20990101_000001_kw.md"
run2 ./scripts/rebuild-index.sh >/dev/null 2>&1
! grep -q zebracode "$w2/KNOWLEDGE/INDEX.md" && grep -q 'Kw.md.*\[kw: zebracode' "$w2/KNOWLEDGE/INDEX.full.md"
check "R35 KNOWLEDGE keywords go to INDEX.full.md only, never the loaded INDEX.md" $?
run2 ./scripts/memory-find.sh --knowledge zebracode | grep -q 'fam/Kw.md' && run2 ./scripts/memory-find.sh quokkaword | grep -q '20990101_000001_kw.md' \
  && ! run2 ./scripts/memory-find.sh quokkaword | grep -q '\[body\]'
check "R35 keywords are found from the index (MEMORY and --knowledge), no body fallback" $?
out=$(run2 ./scripts/memory-find.sh flamingo); printf '%s\n' "$out" | grep -q '^> keywords: flamingo$'
check "R35 a body-only hit prints a ready-to-paste keywords line" $?
out=$(run2 ./scripts/validate.sh --content 2>&1); ! printf '%s' "$out" | grep -q 'MULTILINE.*Kw.md'
check "R35 a keywords line right under the summary is not a multi-line summary" $?
printf '# L\n> summary: long kw\n> keywords: %s\n\nb\n' "$(printf 'w%.0s' $(seq 1 160))" > "$w2/KNOWLEDGE/fam/Long.md"
run2 ./scripts/rebuild-index.sh >/dev/null 2>&1; out=$(run2 ./scripts/validate.sh --content 2>&1); printf '%s\n' "$out" | grep -q 'LONG keywords.*Long.md'
check "R35 keywords over 150 chars warn" $?
rm -f "$ulog2"; [ -n "${KEEP:-}" ] && echo "$w2" || rm -rf "$w2"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
