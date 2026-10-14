#!/usr/bin/env bash

set -euo pipefail

usage() {
    printf 'Usage: %s SOURCE_IMAGE [DESTINATION_FILENAME]\n' "${0##*/}" >&2
    printf 'Requires NEXTCLOUD_APP_PASSWORD. Optional overrides: NEXTCLOUD_URL (default https://nc.finnokeeffe.nz),\n' >&2
    printf 'NEXTCLOUD_USER (default whimsical), NEXTCLOUD_VAULT_DIR (default obsidian_vault).\n' >&2
}

if (( $# < 1 || $# > 2 )); then
    usage
    exit 2
fi

source_image=$1
requested_name=${2:-${source_image##*/}}
nextcloud_url=${NEXTCLOUD_URL:-https://nc.finnokeeffe.nz}
nextcloud_user=${NEXTCLOUD_USER:-whimsical}
vault_dir=${NEXTCLOUD_VAULT_DIR:-obsidian_vault}

if [[ -z ${NEXTCLOUD_APP_PASSWORD:-} ]]; then
    printf 'Error: NEXTCLOUD_APP_PASSWORD is not set.\n' >&2
    exit 1
fi

if [[ ! -f $source_image ]]; then
    printf 'Error: source image is not a regular file: %s\n' "$source_image" >&2
    exit 1
fi

source -- "$(dirname -- "${BASH_SOURCE[0]}")/image-name-checks.sh"

# Percent-encode each segment of a slash-separated path.
encode_path() {
    jq -rn --arg path "$1" '$path | split("/") | map(@uri) | join("/")'
}

curl_quote() {
    local value=${1//\\/\\\\}
    printf '%s' "${value//\"/\\\"}"
}

# The credentials go to curl as a config file on a pipe, so the password never
# appears in the process list.
nextcloud_curl() {
    curl --silent --show-error \
        --config <(printf 'user = "%s:%s"\n' "$(curl_quote "$nextcloud_user")" "$(curl_quote "$NEXTCLOUD_APP_PASSWORD")") \
        "$@"
}

attachments_url=${nextcloud_url%/}/remote.php/dav/files/$(encode_path "$nextcloud_user")/$(encode_path "${vault_dir%/}")/Attachments

response_body=$(mktemp)
trap 'rm -f -- "$response_body"' EXIT

fail_with_response() {
    printf 'Error: %s (HTTP %s)\n' "$1" "$2" >&2
    if [[ -s $response_body ]]; then
        cat -- "$response_body" >&2
        printf '\n' >&2
    fi
    exit 1
}

status=$(nextcloud_curl --request PROPFIND --header 'Depth: 0' \
    --output "$response_body" --write-out '%{http_code}' -- "$attachments_url/")
case $status in
    207) ;;
    401) fail_with_response "Nextcloud rejected the credentials for user $nextcloud_user" "$status" ;;
    404) fail_with_response "attachment directory does not exist: $vault_dir/Attachments" "$status" ;;
    *) fail_with_response "could not check $vault_dir/Attachments" "$status" ;;
esac

# If-None-Match: * makes Nextcloud refuse to replace an existing file (HTTP 412),
# so a taken name moves on to the next numeric suffix instead of overwriting.
candidate=$filename_stem.$source_extension
suffix=2
while true; do
    status=$(nextcloud_curl --upload-file "$source_image" --header 'If-None-Match: *' \
        --output "$response_body" --write-out '%{http_code}' -- "$attachments_url/$(encode_path "$candidate")")
    case $status in
        201) break ;;
        412)
            candidate=$filename_stem-$suffix.$source_extension
            ((suffix += 1))
            ;;
        *) fail_with_response "upload of Attachments/$candidate failed" "$status" ;;
    esac
done

printf 'Attachments/%s\n' "$candidate"
