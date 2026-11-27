# .agentic_context — Requirements

Numbered, testable behavioural rules for the scripts in `scripts/`. Add a
requirement here in the same session as any change to them
(see `AGENTS.md`). These R-numbers are the ones the scripts' comments and
`scripts/test-*.sh` checks cite; the viewer and MCP server keep their own
numbering in `documents/REQUIREMENTS.md`. Run `scripts/test-rebuild-index.sh` to verify.

## Index generation (`rebuild-index.sh`)

**R1.** A MEMORY finding whose summary begins `[STALE` MUST be routed to the
`## superseded/` tail section of `MEMORY/INDEX.md`, out of the active list.

**R2.** A MEMORY finding whose summary begins `[STALE`, `[PROMOTE?`, or
`[REVIEWED` MUST NOT receive the automatic
`[PROMOTE? auto — used in N domains]` tag, regardless of how many `**Used in:**`
domains it lists. A superseded, already-flagged, or explicitly-rejected finding
is not an open promotion candidate.

**R3.** The prefix keywords in R1/R2 MUST be matched on the opening bracket
alone. Each keyword may be followed by an explanation inside the same brackets
(`[STALE — superseded by <file>]`), so matching a closing `]` immediately after
the keyword silently disables both rules.

**R4.** A MEMORY finding with no recognised prefix and ≥3 distinct `**Used in:**`
domains MUST receive the automatic promotion tag.

## Integrity check (`validate.sh`)

**R5.** `validate.sh` MUST report a STRAY and exit non-zero for any
non-hidden entry at the context root other than `AGENTS.md`, `CLAUDE.md`,
`MAIN_PROMPT.md`, `README.md`, `REFERENCE.md`, `REQUIREMENTS.md`, `CHANGELOG.md`, `VERSION`, `LICENSE`,
`KNOWLEDGE/`, `MEMORY/`, `SKILLS/`, `POLICIES/` and `scripts/`. (Found on a live deployment:
~1.6 MB of `tmp_*` sweep logs sat committed at the root for a month, unflagged.)

**R6.** `validate.sh` MUST warn (never fail, exit code unchanged) for a MEMORY
finding whose summary starts `[STALE — superseded` and has no `**Superseded-by:**`
line, whose named `.md` target does not exist, or whose target (when under
`MEMORY/`) has no `**Corrects:**` line naming the stale file. Other `[STALE`
wording is not flagged.

**R7.** In the superseded tail section, `rebuild-index.sh` MUST print
`-> <replacement>` after a stale entry that carries `**Superseded-by:**`.

## Two-tier MEMORY index (`rebuild-index.sh`, `memory-find.sh`)

**R8.** `MEMORY/INDEX.md` (loaded at bootstrap) MUST be a slug map — slug,
finding count, one-line scope from `MEMORY/SLUGS.tsv` — plus the
`[PROMOTE?]` entries, and MUST NOT list ordinary finding summaries. The full
per-finding catalogue goes to `MEMORY/INDEX.full.md`, written before
`INDEX.md` so the freshness check holds. R1-R4 and R7 apply to the full file.

**R9.** A `MEMORY/<slug>/` folder with no `MEMORY/SLUGS.tsv` row MUST be warned
about on stderr by `rebuild-index.sh` (never fail).

**R10.** `scripts/memory-find.sh <kw…>` MUST search `INDEX.full.md`
case-insensitively, require every keyword to match, and cap output at 15 hits.
(Extended by R26-R28.)

## Bootstrap stats (`stats.sh`)

**R11.** The `BOOTSTRAP LOAD` table MUST list every file read at bootstrap
(including each folder's `SKILL.md` and every `[CORE]` KNOWLEDGE doc) by its
path relative to `<root>` (`~/` outside it), with an est. token count, and the
total line MUST state the file count. A listed file that does not exist MUST
print as `(MISSING)`, never be silently skipped.

**R12.** The SKILLS section MUST follow category symlinks (an install may link
its skill categories in from a shared skills repo) and count each `SKILL.md` as
one skill. (Found on a live deployment: it reported `files: 0` because plain
`find` does not follow symlinks.)

**R13.** The bootstrap prompt is `MAIN_PROMPT.md` inside the root, else a
`context.md` beside it. If that prompt names a root-level `.md` file that exists but is not
in the bootstrap list, `stats.sh` MUST print a `WARNING` line above the total
(never fail). `CHANGELOG.md` is exempt: the prompt names it as history, it is
never loaded.

## Usage log (`memory-find.sh`, `usage-report.sh`)

**R14.** Every `memory-find.sh` search MUST append one tab-separated line
`date<TAB>keywords<TAB>hit-count<TAB>mode` (mode = `index`, `body` or `none`)
to `$AGENTIC_USAGE_LOG` (default `~/.agentic-context-usage.log`), including
zero-hit searches; a logging
failure MUST NOT fail the search. `scripts/usage-report.sh` summarises that log
(search count, top queries, zero-hit queries).

**R15.** `scripts/set-slug.sh <slug> "<description>"` MUST add or replace exactly
one `slug<TAB>description` row in `MEMORY/SLUGS.tsv`, keep the file sorted by
slug, and refuse a slug with no `MEMORY/<slug>/` folder or a description that is
empty or contains a tab or newline. `rebuild-index.sh` MUST NOT write
`SLUGS.tsv`: it is hand-written source, and two machines appending the same row
would conflict on the next `pull --rebase`.

**R16.** `validate.sh` MUST warn, never fail, when a `MEMORY/<slug>/` folder has
no `SLUGS.tsv` row (naming `set-slug.sh` as the fix) and when a row names a
folder that does not exist. A missing description is cosmetic and must not block
the bootstrap's self-heal step.

**R17.** `set-slug.sh` MUST refuse a slug that is empty, contains `/`, or starts
with `.`: a slug is a plain folder name directly under `MEMORY/`, and
`[ -d MEMORY/$slug ]` alone accepts `""` and `../KNOWLEDGE`.

**R18.** With no `MEMORY/<slug>/` folders, `rebuild-index.sh` MUST write a slim
index that says so (no literal `*/` glob row), and `memory-find.sh` MUST exit 0
with `no findings match` (and log the search), not abort silently.

**R19.** `validate.sh` MUST report `MEMORY/INDEX.md` as stale when
`MEMORY/SLUGS.tsv` is newer than it, since the slug descriptions are part of
that index.

## System version (`bump-version.sh`, `validate.sh`, `rebuild-index.sh`, `stats.sh`)

The system files are the ones that travel unchanged between installs:
`scripts/*.sh`, the three folder `SKILL.md` skeletons, this file and the
bootstrap prompt. Docs, findings and skills are content; git versions those.

**R20.** The context root MUST hold a `VERSION` file with one `X.Y.Z` line and a
`CHANGELOG.md` whose newest `## ` entry starts with that version. `validate.sh`
MUST warn (never fail) when `VERSION` is missing or malformed, or the two
disagree. No file carries a hand-written version line.

**R21.** `scripts/bump-version.sh <major|minor|patch|X.Y.Z> "<line>"` MUST write
the new version to `VERSION`, add a dated entry with that line at the top of
`CHANGELOG.md`, rewrite the bootstrap prompt's title to end
` (system vX.Y.Z)` (replacing an earlier stamp, not appending), and rewrite
`scripts/.system-manifest` (sha256 + path of every system file). It MUST refuse
an empty changelog line or a malformed version and leave `VERSION` unchanged.
`bump-version.sh --restamp` MUST do only the last two (prompt title and
manifest) for the current version, leaving `VERSION` and `CHANGELOG.md`
untouched, and MUST refuse when `VERSION` is missing or malformed. (A copy of the
system made for another install is restamped, not bumped.)

**R22.** `validate.sh` MUST warn, never fail, when a file in the manifest is
gone or its hash differs, when a `scripts/*.sh` file is not in the manifest, or
when the bootstrap prompt's title does not carry the current version. The fix
it names is `bump-version.sh`. The manifest names the bootstrap prompt
`MAIN_PROMPT.md` whether it sits inside the root or beside it, and `validate.sh`
MUST look in both places. (A changed script with no version bump is how
two installs end up running different systems under one name.)

**R23.** With a `VERSION` file present, `rebuild-index.sh` MUST stamp
`System vX.Y.Z.` into the header of all four derived indexes, and `stats.sh`
MUST print the version in a `== SYSTEM ==` section.

## One-call bootstrap (`bootstrap.sh`)

**R24.** `scripts/bootstrap.sh` MUST, in one run: pull the repo with
`--rebase --autostash` (skipped with `--no-pull` or outside a git clone with a
remote), rebuild the indexes, run `validate.sh` and print its findings and
verdict, list the absolute paths of the files to read (rule files, each
folder's `SKILL.md` and `INDEX.md`, every `[CORE]` doc), list each
`MEMORY/handoff/` finding whose summary does not start with `[STALE`, and print
`stats.sh` last under a `== STATS` heading. It MUST exit non-zero when the pull
or the validation fails.

## Summary size (`validate.sh`)

**R25.** `validate.sh` MUST warn, never fail, for a KNOWLEDGE summary longer
than 200 characters, a skill `description:` longer than 300, and a MEMORY
summary longer than 300. A MEMORY finding whose filename date is before
`MEMORY_CAP_SINCE` (default 20261116) MUST only be counted in one total line,
not listed. Limits are overridable (`AGENTIC_SUMMARY_MAX`,
`AGENTIC_SKILL_DESC_MAX`, `AGENTIC_MEMORY_SUMMARY_MAX`,
`AGENTIC_MEMORY_CAP_SINCE`). (KNOWLEDGE/INDEX.md cost 3.6k tokens in every
session because 22 of 24 summaries were paragraphs.)

## Search recall (`memory-find.sh`, `rebuild-index.sh`, `usage-report.sh`)

**R26.** When no index line matches, `memory-find.sh` MUST search the finding
files themselves (same AND, case-insensitive rule), print each hit as
`[body]` with its summary, and log the search with mode `body`. (39 of the
first 103 logged searches returned nothing.)

**R27.** A slug whose `MEMORY/SLUGS.tsv` description starts with `[ARCHIVE]`
MUST be left out of `memory-find.sh` results unless `--all` is given, and the
output MUST say how many hits were left out, including when there is no other
hit.

**R28.** A finding's optional `**Keywords:**` line MUST be appended to its
index line as ` [kw: …]`, so `memory-find.sh` matches those terms without a
body search.

**R30.** `usage-report.sh --today` MUST list today's zero-hit searches and
today's body-only hits (the session debrief reviews both).

## Expiry (`validate.sh`)

**R29.** A KNOWLEDGE doc or MEMORY finding may carry `**Verify-by:**
YYYY-MM-DD`. `validate.sh` MUST warn, never fail, when that date has passed or
is not a date, and MUST skip a `[STALE` finding.

## Speed (`lib.sh`)

**R31.** `rebuild-index.sh` and `validate.sh` MUST read doc header fields and
compute the summary/body hashes in a fixed number of passes (`scripts/lib.sh`),
not in per-file processes, and MUST produce the same index lines, hash cache
and findings as before. (At ~690 docs the per-file version took 41 s + 38 s of
every bootstrap; now about 2 s + 1 s.) The hash join MUST work on an empty
cache (a new install).

## Usage tracking (`mark-used.sh`)

**R32.** `scripts/mark-used.sh <finding> <domain>` MUST add the domain to the
finding's `**Used in:**` line, creating the line when absent without breaking
the blank line after the summary, MUST NOT duplicate a domain (case-insensitive),
and MUST refuse a file outside `MEMORY/<slug>/` or a domain containing a comma.

**R33.** `rebuild-index.sh` and `validate.sh` MUST stop with exit 2 and a message
naming `scripts/lib.sh` and the fix (copy the whole `scripts/` folder) when that
file is missing, instead of a bare `No such file` from the `source` line. (An
install that copied single scripts by hand, or an older copy upgraded script by
script, hits this.)

**R34.** A context root MAY hold a `POLICIES/` folder of extra rule files a user
keeps beside the framework's own `AGENTS.md`. `bootstrap.sh` MUST list every
`POLICIES/*.md` under READ NEXT, right after `AGENTS.md`, in name order, and the
bootstrap prompt MUST tell the agent to read them all and follow them like
`AGENTS.md`; the folder is optional and its absence is not an error. `stats.sh`
MUST count each file in its bootstrap load. `validate.sh` MUST accept the folder
at the root and report a STRAY (non-zero exit) for anything inside it that is not
a `.md` file, since nothing else is read. The framework ships no `POLICIES/`
content.

**R35.** Any KNOWLEDGE doc or MEMORY finding MAY carry one `> keywords:` line
right under its `> summary:` line (the older `**Keywords:**` body line still
counts). `rebuild-index.sh` MUST append the keywords to that doc's line in
`MEMORY/INDEX.full.md` or `KNOWLEDGE/INDEX.full.md`, never to the loaded
`KNOWLEDGE/INDEX.md`, so they cost no session tokens. `memory-find.sh
--knowledge` MUST search KNOWLEDGE the same way MEMORY is searched. A body-only
hit MUST print a ready-to-paste `> keywords:` line built from the query.
`validate.sh` MUST accept the keywords line under the summary and warn when it
is over 150 characters (`KEYWORDS_MAX`).
