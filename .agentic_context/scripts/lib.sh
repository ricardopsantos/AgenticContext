#!/usr/bin/env bash
# summary: Shared one-pass scanners for rebuild-index.sh and validate.sh (header fields and summary/body hashes for many docs in a few processes); sourced, never run.
# Why this exists (R31): the scripts used to start ~10 processes per doc. At
# ~700 docs that made rebuild + validate take ~80 s of every session bootstrap.
# Both scanners read file paths on stdin (one per line, relative to the root).

US=$'\x1f'   # field separator: not whitespace, so `IFS=$US read` keeps empty fields

# scan_docs → one row per non-empty file, fields separated by $US:
#   path, bytes, count of summary lines, summary, line after the first summary,
#   has-Used-in (0/1), Used in, Superseded-by, Keywords, has-Verify-by (0/1), Verify-by
# Each value is the first matching line with its "**Field:** " prefix removed.
scan_docs () {
  tr '\n' '\0' | LC_ALL=C xargs -0 awk -v s="$US" '
    function emit() {
      if (cur == "") return
      gsub(/[ \t\r]+$/, "", ver)
      printf "%s%s%d%s%d%s%s%s%s%s%d%s%s%s%s%s%s%s%d%s%s\n", cur, s, bytes, s, nsum, s, sum, s, after, s, hasu, s, used, s, sup, s, kw, s, hasv, s, ver
    }
    FNR == 1 { emit(); cur = FILENAME; bytes = 0; nsum = 0; sum = after = used = sup = kw = ver = ""; hasu = hasv = hass = hask = 0; want = 0 }
    { bytes += length($0) + 1 }
    want { after = $0; want = 0 }
    /^> summary:/ { nsum++; if (nsum == 1) { sum = $0; sub(/^> summary: /, "", sum); want = 1 } }
    !hasu && /^\*\*Used in:\*\*/        { hasu = 1; used = $0; sub(/^\*\*Used in:\*\* */, "", used) }
    !hass && /^\*\*Superseded-by:\*\*/  { hass = 1; sup = $0;  sub(/^\*\*Superseded-by:\*\* */, "", sup) }
    !hask && /^\*\*Keywords:\*\*/       { hask = 1; kw = $0;   sub(/^\*\*Keywords:\*\* */, "", kw) }
    !hasv && /^\*\*Verify-by:\*\*/      { hasv = 1; ver = $0;  sub(/^\*\*Verify-by:\*\* */, "", ver) }
    END { emit() }
  ' /dev/null
}

# hash_table → "summary-hash<TAB>body-hash<TAB>path" per file. Same definitions
# as scripts/.summary-hashes has always used: sha256 of the first summary line
# (description: line under SKILLS/) without its newline, and sha256 of the file
# with every such line removed. A file with no row gets the empty-input hash.
hash_table () {
  local tmp list; tmp=$(mktemp -d); list=$(mktemp)
  cat > "$list"
  tr '\n' '\0' < "$list" | LC_ALL=C xargs -0 awk -v d="$tmp" '
    FNR == 1 {
      if (out != "") { close(out ".s"); close(out ".b") }
      n = FILENAME; gsub("/", "%", n); out = d "/" n
      pat = (FILENAME ~ /^SKILLS\//) ? "^description:" : "^> summary:"
      printf "" > (out ".s"); printf "" > (out ".b"); got = 0
    }
    $0 ~ pat { if (!got) { printf "%s", $0 > (out ".s"); got = 1 } next }
    { print > (out ".b") }
  ' /dev/null
  ( cd "$tmp" && find . -type f | sed 's|^\./||' | tr '\n' '\0' | xargs -0 shasum -a 256 2>/dev/null ) > "$list.sums"
  awk -v sums="$list.sums" -v empty="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" '
    BEGIN { while ((getline l < sums) > 0) {
              h = l; sub(/ .*/, "", h); n = l; sub(/^[0-9a-f]+ [ *]/, "", n)
              kind = substr(n, length(n)); n = substr(n, 1, length(n) - 2); gsub("%", "/", n)
              if (kind == "s") S[n] = h; else B[n] = h } }
    { printf "%s\t%s\t%s\n", ($0 in S ? S[$0] : empty), ($0 in B ? B[$0] : empty), $0 }
  ' "$list"
  rm -rf "$tmp" "$list" "$list.sums"
}
