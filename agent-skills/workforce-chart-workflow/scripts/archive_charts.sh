#!/usr/bin/env bash
set -euo pipefail

if (( $# != 1 )); then
    printf 'Usage: %s CHART_DIRECTORY\n' "${0##*/}" >&2
    exit 2
fi

chart_directory=${1%/}
mkdir -p -- "$chart_directory"
chart_directory="$(cd -- "$chart_directory" && pwd)"

chart_files=()
while IFS= read -r -d '' chart_file; do
    chart_files+=("$chart_file")
done < <(
    find "$chart_directory" -maxdepth 1 -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
           -o -iname '*.gif' -o -iname '*.webp' \) \
        -print0
)

if (( ${#chart_files[@]} == 0 )); then
    printf 'No existing charts to archive in %s\n' "$chart_directory"
    exit 0
fi

archive_root="$chart_directory/archive"
archive_stamp=$(date -u +%Y%m%dT%H%M%SZ)
archive_directory="$archive_root/$archive_stamp"
archive_suffix=1

while [[ -e $archive_directory ]]; do
    archive_directory="$archive_root/$archive_stamp-$archive_suffix"
    ((archive_suffix += 1))
done

mkdir -p "$archive_directory"
mv -- "${chart_files[@]}" "$archive_directory/"
printf 'Archived %d chart(s) to %s\n' "${#chart_files[@]}" "$archive_directory"
