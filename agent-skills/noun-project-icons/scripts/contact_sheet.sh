#!/usr/bin/env bash
# Build a labelled contact sheet of Noun Project search results for choosing icons.
# Usage: contact_sheet.sh OUTPUT.png ICON_ID [ICON_ID ...]
# Thumbnails are the public 200 px previews the search page shows; they need no sign-in.
set -euo pipefail

if [[ $# -lt 2 ]]; then
	echo "Usage: $0 OUTPUT.png ICON_ID [ICON_ID ...]" >&2
	exit 2
fi

output=$1
shift
thumbs=$(mktemp -d)
trap 'rm -rf "$thumbs"' EXIT

for id in "$@"; do
	if [[ ! $id =~ ^[0-9]+$ ]]; then
		echo "Skipping non-numeric icon ID: $id" >&2
		continue
	fi
	if ! curl -sSf --max-time 20 -o "$thumbs/$id.png" "https://static.thenounproject.com/png/$id-200.png"; then
		echo "Could not fetch thumbnail for $id" >&2
		rm -f "$thumbs/$id.png"
	fi
done

files=()
for id in "$@"; do
	[[ -f "$thumbs/$id.png" ]] && files+=("$thumbs/$id.png")
done
if [[ ${#files[@]} -eq 0 ]]; then
	echo "No thumbnails fetched." >&2
	exit 1
fi

magick montage -label '%t' "${files[@]}" -background white -tile 8x \
	-geometry 120x120+10+10 -pointsize 14 "$output"
echo "$output"
