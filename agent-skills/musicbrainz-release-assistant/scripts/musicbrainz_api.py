#!/usr/bin/env python3
"""Small read-only MusicBrainz WS/2 client for release research."""

from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import sys
import time
from typing import NoReturn
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


BASE_URL = "https://musicbrainz.org/ws/2"
ENTITIES = (
    "area",
    "artist",
    "event",
    "label",
    "place",
    "recording",
    "release",
    "release-group",
    "series",
    "work",
    "url",
)
RATE_LOCK = Path("/tmp/musicbrainz-release-assistant-rate-limit")
MIN_INTERVAL_SECONDS = 1.1


def fail(message: str, code: int = 2) -> NoReturn:
    print(json.dumps({"error": message}, ensure_ascii=False), file=sys.stderr)
    raise SystemExit(code)


def user_agent() -> str:
    contact = os.environ.get("MUSICBRAINZ_CONTACT", "").strip()
    if not contact:
        fail(
            "MUSICBRAINZ_CONTACT is required. Set it to a contact email or URL, "
            "or use browser research instead."
        )
    if any(character in contact for character in "\r\n"):
        fail("MUSICBRAINZ_CONTACT must not contain line breaks.")
    return f"MusicBrainzReleaseAssistant/1.0 ({contact})"


def wait_for_rate_slot() -> None:
    RATE_LOCK.touch(mode=0o600, exist_ok=True)
    with RATE_LOCK.open("r+", encoding="utf-8") as handle:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        raw = handle.read().strip()
        try:
            last_request = float(raw) if raw else 0.0
        except ValueError:
            last_request = 0.0
        delay = MIN_INTERVAL_SECONDS - (time.time() - last_request)
        if delay > 0:
            time.sleep(delay)
        handle.seek(0)
        handle.truncate()
        handle.write(str(time.time()))
        handle.flush()
        os.fsync(handle.fileno())
        fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def request_json(path: str, params: dict[str, str | int]) -> object:
    query = dict(params)
    query["fmt"] = "json"
    url = f"{BASE_URL}/{path}?{urlencode(query)}"
    wait_for_rate_slot()
    request = Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": user_agent(),
        },
        method="GET",
    )
    try:
        with urlopen(request, timeout=30) as response:
            return json.load(response)
    except HTTPError as error:
        retry = error.headers.get("Retry-After")
        suffix = f" Retry-After: {retry}." if retry else ""
        fail(f"MusicBrainz returned HTTP {error.code}.{suffix}", 1)
    except URLError as error:
        fail(f"Could not reach MusicBrainz: {error.reason}", 1)
    except (TimeoutError, json.JSONDecodeError) as error:
        fail(f"MusicBrainz response could not be read: {error}", 1)


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(
        description="Read-only MusicBrainz WS/2 search and lookup helper."
    )
    commands = root.add_subparsers(dest="command", required=True)

    search = commands.add_parser("search", help="Search an entity index")
    search.add_argument("entity", choices=ENTITIES)
    search.add_argument("query", help="MusicBrainz Lucene search query")
    search.add_argument("--limit", type=int, default=25)
    search.add_argument("--offset", type=int, default=0)

    lookup = commands.add_parser("lookup", help="Look up an entity by MBID")
    lookup.add_argument("entity", choices=ENTITIES)
    lookup.add_argument("mbid")
    lookup.add_argument(
        "--inc",
        default="",
        help="Comma- or plus-separated MusicBrainz inc values",
    )
    return root


def main() -> None:
    args = parser().parse_args()
    if args.command == "search":
        if not 1 <= args.limit <= 100:
            fail("--limit must be between 1 and 100.")
        if args.offset < 0:
            fail("--offset must be non-negative.")
        result = request_json(
            args.entity,
            {"query": args.query, "limit": args.limit, "offset": args.offset},
        )
    else:
        params: dict[str, str | int] = {}
        if args.inc:
            params["inc"] = "+".join(
                part.strip()
                for part in args.inc.replace("+", ",").split(",")
                if part.strip()
            )
        result = request_json(f"{args.entity}/{args.mbid}", params)
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2, sort_keys=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
