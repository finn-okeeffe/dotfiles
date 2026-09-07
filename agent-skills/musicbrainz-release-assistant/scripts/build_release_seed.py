#!/usr/bin/env python3
"""Build a user-reviewed HTML POST form for the MusicBrainz release seeder."""

from __future__ import annotations

import argparse
from html import escape
import json
from pathlib import Path
import re
import sys
from typing import Any, NoReturn


ACTION = "https://musicbrainz.org/release/add"
PARTIAL_DATE = re.compile(r"^(\d{4})(?:-(\d{2})(?:-(\d{2}))?)?$")


def fail(message: str) -> NoReturn:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(2)


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"could not read {path}: {error}")
    if not isinstance(value, dict):
        fail("release draft must be a JSON object")
    return value


def add(fields: list[tuple[str, str]], name: str, value: Any) -> None:
    if value is None or value == "":
        return
    fields.append((name, str(value)))


def add_artist_credit(
    fields: list[tuple[str, str]], prefix: str, credit: object
) -> None:
    if not isinstance(credit, list):
        return
    for index, item in enumerate(credit):
        if not isinstance(item, dict):
            fail(f"{prefix}[{index}] must be an object")
        base = f"{prefix}.names.{index}"
        add(fields, f"{base}.mbid", item.get("mbid"))
        add(fields, f"{base}.name", item.get("name"))
        add(fields, f"{base}.artist.name", item.get("artist_name"))
        add(fields, f"{base}.join_phrase", item.get("join_phrase"))


def build_fields(draft: dict[str, Any]) -> list[tuple[str, str]]:
    unresolved = draft.get("unresolved", [])
    if not isinstance(unresolved, list):
        fail("unresolved must be an array")
    blockers = [
        item.get("field", "unknown")
        for item in unresolved
        if isinstance(item, dict) and item.get("severity") == "required"
    ]
    if blockers:
        fail("required unresolved fields remain: " + ", ".join(blockers))

    identity = draft.get("identity")
    release = draft.get("release")
    media = draft.get("media")
    if not isinstance(identity, dict) or not isinstance(release, dict):
        fail("identity and release must be objects")
    if not isinstance(media, list) or not media:
        fail("media must be a non-empty array")
    if identity.get("exact_match_status") != "no_exact_release":
        fail("seed generation requires identity.exact_match_status=no_exact_release")
    if not release.get("name"):
        fail("release.name is required")
    if not isinstance(release.get("artist_credit"), list) or not release.get("artist_credit"):
        fail("release.artist_credit must be a non-empty array")

    fields: list[tuple[str, str]] = []
    add(fields, "name", release.get("name"))
    release_group_mbid = identity.get("release_group_mbid")
    if release_group_mbid:
        add(fields, "release_group", release_group_mbid)
    else:
        types = identity.get("release_group_types", [])
        if not isinstance(types, list) or not types:
            fail("release_group_mbid or at least one release_group_type is required")
        for release_type in types:
            add(fields, "type", release_type)

    for key in (
        "comment",
        "annotation",
        "barcode",
        "language",
        "script",
        "status",
        "packaging",
    ):
        add(fields, key, release.get(key))

    add_artist_credit(fields, "artist_credit", release.get("artist_credit"))

    events = release.get("events", [])
    if not isinstance(events, list):
        fail("release.events must be an array")
    for index, event in enumerate(events):
        if not isinstance(event, dict):
            fail(f"release.events[{index}] must be an object")
        date = event.get("date")
        if date:
            match = PARTIAL_DATE.fullmatch(str(date))
            if not match:
                fail(f"release.events[{index}].date must be YYYY, YYYY-MM, or YYYY-MM-DD")
            year, month, day = match.groups()
            add(fields, f"events.{index}.date.year", year)
            add(fields, f"events.{index}.date.month", month)
            add(fields, f"events.{index}.date.day", day)
        add(fields, f"events.{index}.country", event.get("country"))

    labels = release.get("labels", [])
    if not isinstance(labels, list):
        fail("release.labels must be an array")
    for index, label in enumerate(labels):
        if not isinstance(label, dict):
            fail(f"release.labels[{index}] must be an object")
        add(fields, f"labels.{index}.mbid", label.get("mbid"))
        add(fields, f"labels.{index}.name", label.get("name"))
        add(fields, f"labels.{index}.catalog_number", label.get("catalog_number"))

    for medium_index, medium in enumerate(media):
        if not isinstance(medium, dict):
            fail(f"media[{medium_index}] must be an object")
        tracks = medium.get("tracks")
        if not isinstance(tracks, list) or not tracks:
            fail(f"media[{medium_index}].tracks must be a non-empty array")
        if not medium.get("format"):
            fail(f"media[{medium_index}].format is required")
        add(fields, f"mediums.{medium_index}.format", medium.get("format"))
        add(fields, f"mediums.{medium_index}.name", medium.get("title"))
        for track_index, track in enumerate(tracks):
            if not isinstance(track, dict) or not track.get("title"):
                fail(f"media[{medium_index}].tracks[{track_index}] needs a title")
            prefix = f"mediums.{medium_index}.track.{track_index}"
            add(fields, f"{prefix}.name", track.get("title"))
            add(fields, f"{prefix}.number", track.get("number"))
            add(fields, f"{prefix}.recording", track.get("recording_mbid"))
            add(fields, f"{prefix}.length", track.get("length"))
            add_artist_credit(fields, f"{prefix}.artist_credit", track.get("artist_credit"))

    urls = release.get("urls", [])
    if not isinstance(urls, list):
        fail("release.urls must be an array")
    for index, item in enumerate(urls):
        if not isinstance(item, dict) or not item.get("url"):
            fail(f"release.urls[{index}] needs a URL")
        add(fields, f"urls.{index}.url", item.get("url"))
        add(fields, f"urls.{index}.link_type", item.get("link_type"))

    add(fields, "edit_note", draft.get("edit_note"))
    return fields


def render(fields: list[tuple[str, str]], draft_name: str) -> str:
    hidden = "\n".join(
        f'      <input type="hidden" name="{escape(name, quote=True)}" '
        f'value="{escape(value, quote=True)}">'
        for name, value in fields
    )
    rows = "\n".join(
        "          <tr><th>"
        + escape(name)
        + "</th><td>"
        + escape(value)
        + "</td></tr>"
        for name, value in fields
    )
    return f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Review and open MusicBrainz release editor</title>
    <style>
      body {{ font-family: system-ui, sans-serif; max-width: 70rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; }}
      button {{ font: inherit; padding: .7rem 1rem; }}
      table {{ border-collapse: collapse; width: 100%; overflow-wrap: anywhere; }}
      th, td {{ border: 1px solid #bbb; padding: .35rem; text-align: left; vertical-align: top; }}
      th {{ width: 35%; }}
      .warning {{ border-left: .3rem solid #b55; padding-left: 1rem; }}
    </style>
  </head>
  <body>
    <h1>MusicBrainz release seed</h1>
    <p>Generated from <code>{escape(draft_name)}</code>.</p>
    <p class="warning"><strong>Review required:</strong> this opens a prefilled MusicBrainz form. It does not submit an edit automatically. Confirm the exact edition, matched entities, recordings, and every rendered field before submitting on MusicBrainz.</p>
    <form action="{ACTION}" method="post" enctype="multipart/form-data">
{hidden}
      <button type="submit">Open the prefilled MusicBrainz release editor</button>
    </form>
    <details>
      <summary>Show seeded values</summary>
      <table>
        <tbody>
{rows}
        </tbody>
      </table>
    </details>
  </body>
</html>
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("draft", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    draft = load_json(args.draft)
    fields = build_fields(draft)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render(fields, args.draft.name), encoding="utf-8")
    print(f"wrote {args.output} with {len(fields)} seeded values")


if __name__ == "__main__":
    main()
