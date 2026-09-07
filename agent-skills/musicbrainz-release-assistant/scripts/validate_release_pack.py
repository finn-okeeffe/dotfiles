#!/usr/bin/env python3
"""Validate a MusicBrainz release-assistant work pack."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from typing import Any


REQUIRED_FILES = (
    "release-draft.json",
    "evidence.md",
    "review.md",
    "release-seed.html",
    "follow-up-edits.md",
    "cover-art-manifest.json",
)
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def read_object(path: Path, errors: list[str]) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        errors.append(f"could not read {path.name}: {error}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{path.name} must contain a JSON object")
        return {}
    return value


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def validate_draft(draft: dict[str, Any], errors: list[str], warnings: list[str]) -> None:
    if draft.get("schema_version") != 1:
        errors.append("release-draft.json schema_version must be 1")
    identity = draft.get("identity")
    release = draft.get("release")
    media = draft.get("media")
    if not isinstance(identity, dict):
        errors.append("identity must be an object")
        identity = {}
    if identity.get("exact_match_status") != "no_exact_release":
        errors.append("identity.exact_match_status must be no_exact_release")
    if not identity.get("release_group_mbid") and not identity.get("release_group_types"):
        errors.append("set release_group_mbid or release_group_types")
    if not isinstance(release, dict):
        errors.append("release must be an object")
        release = {}
    if not release.get("name"):
        errors.append("release.name is required")
    credit = release.get("artist_credit")
    if not isinstance(credit, list) or not credit:
        errors.append("release.artist_credit must be a non-empty array")
    if not isinstance(media, list) or not media:
        errors.append("media must be a non-empty array")
    else:
        for medium_index, medium in enumerate(media):
            if not isinstance(medium, dict):
                errors.append(f"media[{medium_index}] must be an object")
                continue
            if not medium.get("format"):
                errors.append(f"media[{medium_index}].format is required")
            tracks = medium.get("tracks")
            if not isinstance(tracks, list) or not tracks:
                errors.append(f"media[{medium_index}].tracks must be non-empty")
                continue
            for track_index, track in enumerate(tracks):
                if not isinstance(track, dict) or not track.get("title"):
                    errors.append(
                        f"media[{medium_index}].tracks[{track_index}].title is required"
                    )

    unresolved = draft.get("unresolved", [])
    if not isinstance(unresolved, list):
        errors.append("unresolved must be an array")
    else:
        for index, item in enumerate(unresolved):
            if not isinstance(item, dict):
                errors.append(f"unresolved[{index}] must be an object")
            elif item.get("severity") == "required":
                errors.append(f"required unresolved field remains: {item.get('field', 'unknown')}")
            elif item.get("severity") == "optional":
                warnings.append(f"optional unresolved field: {item.get('field', 'unknown')}")
            else:
                errors.append(f"unresolved[{index}].severity must be required or optional")

    sources = draft.get("sources", [])
    if not isinstance(sources, list):
        errors.append("sources must be an array")
    else:
        source_ids = [item.get("id") for item in sources if isinstance(item, dict)]
        if any(not source_id for source_id in source_ids):
            errors.append("every source needs an id")
        if len(source_ids) != len(set(source_ids)):
            errors.append("source ids must be unique")
        if not source_ids:
            warnings.append("no structured sources are recorded")


def validate_art(pack: Path, manifest: dict[str, Any], errors: list[str]) -> int:
    if manifest.get("schema_version") != 1:
        errors.append("cover-art-manifest.json schema_version must be 1")
    images = manifest.get("images")
    if not isinstance(images, list):
        errors.append("cover-art-manifest.json images must be an array")
        return 0
    if images and not manifest.get("edit_note"):
        errors.append("cover-art-manifest.json edit_note is required when images are present")
    seen_orders: set[int] = set()
    art_root = pack / "cover-art"
    for index, image in enumerate(images):
        prefix = f"cover-art image {index}"
        if not isinstance(image, dict):
            errors.append(f"{prefix} must be an object")
            continue
        filename = image.get("file")
        relative = Path(filename) if isinstance(filename, str) else Path()
        if not filename or relative.is_absolute() or ".." in relative.parts:
            errors.append(f"{prefix} has an unsafe or missing file path")
            continue
        path = art_root / relative
        if not path.is_file():
            errors.append(f"{prefix} file does not exist: {filename}")
        expected = image.get("sha256")
        if not isinstance(expected, str) or not SHA256.fullmatch(expected):
            errors.append(f"{prefix} needs a lowercase SHA-256 digest")
        elif path.is_file() and digest(path) != expected:
            errors.append(f"{prefix} SHA-256 does not match: {filename}")
        order = image.get("order")
        if not isinstance(order, int) or order < 1:
            errors.append(f"{prefix} order must be a positive integer")
        elif order in seen_orders:
            errors.append(f"{prefix} order is duplicated: {order}")
        else:
            seen_orders.add(order)
        types = image.get("types")
        if not isinstance(types, list) or not types or not all(
            isinstance(value, str) and value for value in types
        ):
            errors.append(f"{prefix} needs at least one cover-art type")
        source = image.get("source")
        if not isinstance(source, dict):
            errors.append(f"{prefix} needs source provenance")
        else:
            for field in ("location", "provenance", "exact_edition_evidence"):
                if not source.get(field):
                    errors.append(f"{prefix} source.{field} is required")
    return len(images)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", type=Path)
    args = parser.parse_args()
    pack = args.pack.resolve()
    errors: list[str] = []
    warnings: list[str] = []

    if not pack.is_dir():
        errors.append(f"work pack directory does not exist: {pack}")
    for filename in REQUIRED_FILES:
        path = pack / filename
        if not path.is_file():
            errors.append(f"missing required file: {filename}")
        elif path.stat().st_size == 0:
            errors.append(f"required file is empty: {filename}")
    if not (pack / "cover-art").is_dir():
        errors.append("missing required directory: cover-art")

    draft = read_object(pack / "release-draft.json", errors) if (pack / "release-draft.json").is_file() else {}
    manifest = read_object(pack / "cover-art-manifest.json", errors) if (pack / "cover-art-manifest.json").is_file() else {}
    if draft:
        validate_draft(draft, errors, warnings)
    image_count = validate_art(pack, manifest, errors) if manifest else 0

    result = {
        "valid": not errors,
        "pack": str(pack),
        "cover_art_images": image_count,
        "errors": errors,
        "warnings": warnings,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0 if not errors else 1)


if __name__ == "__main__":
    main()
