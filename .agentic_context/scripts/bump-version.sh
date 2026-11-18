#!/usr/bin/env bash
# summary: Bumps the context system's VERSION, prepends a CHANGELOG.md entry, restamps the bootstrap prompt title and rewrites the system-file hash manifest (--restamp: only the last two); run by hand after changing any system file.
# Usage: bump-version.sh <major|minor|patch|X.Y.Z> "<changelog line>"
#        bump-version.sh --restamp      (keep the version; refresh the prompt title and manifest, e.g. for a copy of the system made for another install)
# The version covers the files that travel between installs (R20-R23): the
# scripts, the three folder SKILL.md skeletons, REQUIREMENTS.md and the bootstrap
# prompt. Docs, findings and skills are content: git alone versions those.
set -euo pipefail
cd "$(dirname "$0")/.."
restamp=0
if [ "${1:-}" = "--restamp" ] && [ $# -eq 1 ]; then restamp=1; how=restamp; msg=""
else
  [ $# -eq 2 ] || { echo 'usage: bump-version.sh <major|minor|patch|X.Y.Z> "<changelog line>" | --restamp' >&2; exit 2; }
  how=$1; msg=$2
  case "$msg" in ""|*$'\n'*) echo "changelog line must be one non-empty line" >&2; exit 1 ;; esac
fi

cur=$(head -n1 VERSION 2>/dev/null | tr -d '[:space:]' || true)
semver='^[0-9]+\.[0-9]+\.[0-9]+$'
case "$how" in
  restamp)
    [[ "$cur" =~ $semver ]] || { echo "VERSION is missing or not X.Y.Z; nothing to restamp" >&2; exit 1; }
    new=$cur ;;
  major|minor|patch)
    [[ "$cur" =~ $semver ]] || { echo "VERSION is missing or not X.Y.Z; pass an explicit version" >&2; exit 1; }
    IFS=. read -r ma mi pa <<<"$cur"
    case "$how" in
      major) new="$((ma+1)).0.0" ;;
      minor) new="${ma}.$((mi+1)).0" ;;
      patch) new="${ma}.${mi}.$((pa+1))" ;;
    esac ;;
  *) [[ "$how" =~ $semver ]] || { echo "version must be major, minor, patch or X.Y.Z" >&2; exit 1; }
     new=$how ;;
esac

if [ "$restamp" -eq 0 ]; then
echo "$new" > VERSION

# Newest entry first, under the title block (everything before the first "## ").
[ -f CHANGELOG.md ] || printf '# Changelog\n\nSystem files only (scripts, SKILL.md skeletons, REQUIREMENTS.md, bootstrap prompt). Written by `scripts/bump-version.sh`.\n' > CHANGELOG.md
head=$(awk '/^## /{exit} {print}' CHANGELOG.md)   # $(…) drops the trailing blank lines
{
  printf '%s\n\n## %s — %s\n- %s\n\n' "$head" "$new" "$(date +%Y-%m-%d)" "$msg"
  awk 'f||/^## /{f=1; print}' CHANGELOG.md
} > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
fi

# The prompt is the one system file pasted or read outside the root, so it carries the version in its title.
BOOT=""
for c in MAIN_PROMPT.md ../MAIN_PROMPT.md; do [ -f "$c" ] && { BOOT=$c; break; }; done
if [ -n "$BOOT" ]; then
  awk -v v="$new" 'NR==1 && /^# /{sub(/ \(system v[0-9.]+\)$/, ""); print $0 " (system v" v ")"; next} {print}' "$BOOT" > "$BOOT.tmp" \
    && cat "$BOOT.tmp" > "$BOOT" && rm -f "$BOOT.tmp"      # cat, not mv: keeps the file's mode and any symlink to it
fi

# Manifest: hash + path of every system file. validate.sh warns when one drifts from it (R22).
{
  ls scripts/*.sh
  for f in KNOWLEDGE/SKILL.md MEMORY/SKILL.md SKILLS/SKILL.md REQUIREMENTS.md; do [ -f "$f" ] && echo "$f"; done
  [ -n "$BOOT" ] && echo "MAIN_PROMPT.md"
} | LC_ALL=C sort | while IFS= read -r f; do
  src=$f; [ "$f" = MAIN_PROMPT.md ] && src=$BOOT   # the prompt sits in the root or beside it; the manifest names it the same either way (R22)
  printf '%s  %s\n' "$(shasum -a 256 < "$src" | cut -d' ' -f1)" "$f"
done > scripts/.system-manifest

echo "version ${cur:-none} -> $new ($(wc -l < scripts/.system-manifest | tr -d ' ') system files in scripts/.system-manifest)"
echo "run scripts/rebuild-index.sh to restamp the indexes"
