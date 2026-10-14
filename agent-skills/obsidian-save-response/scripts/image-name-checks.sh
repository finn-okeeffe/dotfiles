# Filename checks shared by copy-image-to-vault.sh and upload-image-to-nextcloud.sh.
# Source this after setting $source_image and $requested_name. It sets
# $source_extension and $filename_stem, or prints an error and exits.

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
