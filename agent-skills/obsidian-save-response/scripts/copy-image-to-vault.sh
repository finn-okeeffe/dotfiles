#!/usr/bin/env bash

set -euo pipefail

usage() {
    printf 'Usage: %s SOURCE_IMAGE [DESTINATION_FILENAME]\n' "${0##*/}" >&2
    printf 'Set OBSIDIAN_VAULT_PATH to override the default vault root: ~/obsidian-vault\n' >&2
}

if (( $# < 1 || $# > 2 )); then
    usage
    exit 2
fi

source_image=$1
requested_name=${2:-${source_image##*/}}
vault_path=${OBSIDIAN_VAULT_PATH:-"$HOME/obsidian-vault"}
attachments_path=$vault_path/Attachments

if [[ ! -f $source_image ]]; then
    printf 'Error: source image is not a regular file: %s\n' "$source_image" >&2
    exit 1
fi

if [[ ! -d $vault_path ]]; then
    printf 'Error: Obsidian vault directory does not exist: %s\n' "$vault_path" >&2
    exit 1
fi

if [[ ! -d $attachments_path ]]; then
    printf 'Error: attachment directory does not exist: %s\n' "$attachments_path" >&2
    exit 1
fi

if [[ $requested_name == */* || $requested_name == '.' || $requested_name == '..' ]]; then
    printf 'Error: destination filename must not contain a directory path: %s\n' "$requested_name" >&2
    exit 1
fi

source_basename=${source_image##*/}
if [[ $source_basename != *.* || $source_basename == .* ]]; then
    printf 'Error: source image must have a recognised image extension.\n' >&2
    exit 1
fi

source_extension=${source_basename##*.}
source_extension=${source_extension,,}
case $source_extension in
    avif|bmp|gif|heic|heif|jpeg|jpg|png|svg|tif|tiff|webp) ;;
    *)
        printf 'Error: unsupported image extension: .%s\n' "$source_extension" >&2
        exit 1
        ;;
esac

if [[ $requested_name == *.* && $requested_name != .* ]]; then
    requested_extension=${requested_name##*.}
    requested_extension=${requested_extension,,}
    if [[ $requested_extension != "$source_extension" ]]; then
        printf 'Error: destination extension .%s does not match source extension .%s\n' \
            "$requested_extension" "$source_extension" >&2
        exit 1
    fi
    filename_stem=${requested_name%.*}
else
    filename_stem=$requested_name
fi

if [[ -z $filename_stem ]]; then
    printf 'Error: destination filename must have a non-empty stem.\n' >&2
    exit 1
fi

temporary_image=$(mktemp -- "$attachments_path/.obsidian-image-copy.XXXXXX")
cleanup() {
    rm -f -- "$temporary_image"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

if ! cp -- "$source_image" "$temporary_image"; then
    printf 'Error: failed while staging image in: %s\n' "$attachments_path" >&2
    exit 1
fi

candidate=$attachments_path/$filename_stem.$source_extension
suffix=2
while ! ln -- "$temporary_image" "$candidate" 2>/dev/null; do
    if [[ ! -e $candidate && ! -L $candidate ]]; then
        printf 'Error: cannot create attachment: %s\n' "$candidate" >&2
        exit 1
    fi
    candidate=$attachments_path/$filename_stem-$suffix.$source_extension
    ((suffix += 1))
done

cleanup
trap - EXIT HUP INT TERM
printf '%s\n' "$candidate"
