#!/usr/bin/env bash
# Decodes a saved asana_pages.js export in place and checks it against the counts show() returned.
# Usage: check_export.sh FILE CHARS LINES
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 FILE CHARS LINES" >&2
  exit 2
fi
file=$1 chars=$2 lines=$3

sed -i 's/␣/ /g; s/⇥/\t/g' "$file"

# Ignore one trailing newline, which editors and the Write tool may add.
content=$(cat "$file"; printf x)
content=${content%x}
content=${content%$'\n'}
got_chars=$(printf '%s' "$content" | LC_ALL=C.UTF-8 wc -m)
got_lines=$(( $(printf '%s' "$content" | grep -c '' || true) ))

if [[ $got_chars -eq $chars && $got_lines -eq $lines ]]; then
  echo "OK: $got_chars characters, $got_lines lines"
else
  echo "MISMATCH: file has $got_chars characters and $got_lines lines; the page export had $chars and $lines." >&2
  echo "Re-read the export and compare line by line; look for merged or split lines and changed spacing." >&2
  exit 1
fi
