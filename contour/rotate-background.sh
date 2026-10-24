#!/usr/bin/env bash
# Switch Contour to a random background from backgrounds/, different from the current one.
#
# Contour caches a background by its path, so a new image needs a new path in the config.
# Rather than editing the tracked contour.yml, this writes the colour scheme (with the
# chosen background) to colorschemes/gruvbox-dark-hard.yml beside the Flatpak's
# contour.yml, then touches contour.yml so live_config reloads it.
set -euo pipefail

repo_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
config_dir="$HOME/.var/app/org.contourterminal.Contour/config/contour"
scheme_file="$config_dir/colorschemes/gruvbox-dark-hard.yml"

current=""
if [[ -f "$scheme_file" ]]; then
    current="$(sed -n "s/^    path: '\(.*\)'$/\1/p" "$scheme_file")"
fi

mapfile -t images < <(find "$repo_dir/backgrounds" -maxdepth 1 -name '*.png' | sort)
if (( ${#images[@]} == 0 )); then
    echo "No images in $repo_dir/backgrounds" >&2
    exit 1
fi

candidates=()
for image in "${images[@]}"; do
    [[ "$image" != "$current" ]] && candidates+=("$image")
done
(( ${#candidates[@]} == 0 )) && candidates=("${images[@]}")
choice="${candidates[RANDOM % ${#candidates[@]}]}"

mkdir -p "$(dirname "$scheme_file")"
tmp="$(mktemp "$scheme_file.XXXXXX")"
{
    cat "$repo_dir/gruvbox-dark-hard.yml"
    printf '\n# Written by rotate-background.sh; images are pre-blended onto #1d2021.\n'
    printf 'background_image:\n'
    printf "    path: '%s'\n" "$choice"
    printf '    opacity: 1.0\n'
    printf '    blur: false\n'
} > "$tmp"
mv "$tmp" "$scheme_file"

# Changing only the timestamp triggers Contour's live reload without a git diff.
touch "$config_dir/contour.yml"
echo "Contour background: $(basename "$choice")"
