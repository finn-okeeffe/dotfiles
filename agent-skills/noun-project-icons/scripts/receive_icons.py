#!/usr/bin/env python3
"""Save Noun Project icons that a thenounproject.com tab submits to localhost.

Chrome's download buttons open a Save As dialog, and Chrome asks permission
before a public site can fetch() a local address. A top-level form POST needs
neither, so noun_page.js submits the icons as a form to this server, which
saves them, records them in noun-project-icons.json, and redirects the tab back
to Noun Project. Only POSTs to /<random token>/batch are accepted.
"""

from __future__ import annotations

import argparse
import base64
import binascii
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import secrets
import sys
import threading
import time
from urllib.parse import parse_qs


RETURN_ORIGIN = "https://thenounproject.com/"
NAME_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{0,150}\.(svg|png)$")
MAX_BYTES = 100 * 1024 * 1024
MANIFEST = "noun-project-icons.json"


def unique_path(directory: Path, name: str) -> Path:
    target = directory / name
    counter = 1
    while target.exists():
        target = directory / f"{Path(name).stem}-{counter}{Path(name).suffix}"
        counter += 1
    return target


def save_batch(out_dir: Path, payload: dict) -> list[dict]:
    results = []
    records = {record.get("file"): record for record in payload.get("records", [])}
    manifest_path = out_dir / MANIFEST
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else []
    for item in payload.get("files", []):
        name = str(item.get("name", ""))
        if not NAME_PATTERN.match(name):
            results.append({"rejected": name, "reason": "file name"})
            continue
        try:
            data = base64.b64decode(item.get("base64", ""), validate=True)
        except binascii.Error:
            results.append({"rejected": name, "reason": "not base64"})
            continue
        target = unique_path(out_dir, name)
        target.write_bytes(data)
        results.append({"saved": str(target), "bytes": len(data)})
        record = dict(records.get(name, {}))
        record["file"] = target.name
        manifest.append(record)
    for record in payload.get("records", []):
        if "error" in record:
            results.append({"failed": record.get("id"), "error": record["error"]})
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    return results


def make_handler(out_dir: Path, token: str, state: dict) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format: str, *args: object) -> None:
            del format, args  # Keep request logs out of the agent's output.

        def send_text(self, status: int, text: str) -> None:
            data = text.encode()
            self.send_response(status)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_POST(self) -> None:
            parts = self.path.split("?", 1)[0].strip("/").split("/")
            if len(parts) != 2 or not secrets.compare_digest(parts[0], token) or parts[1] != "batch":
                self.send_text(403, "Bad token or path.")
                return
            length = int(self.headers.get("Content-Length") or 0)
            if not 0 < length <= MAX_BYTES:
                self.send_text(413, f"Bad request length: {length}.")
                return
            try:
                fields = parse_qs(self.rfile.read(length).decode("ascii"))
                payload = json.loads(fields["payload"][0])
            except (KeyError, UnicodeDecodeError, json.JSONDecodeError) as error:
                self.send_text(400, f"Could not read the submitted form: {error}")
                return
            results = save_batch(out_dir, payload)
            state["batches"] += 1
            state["last"] = time.time()
            print(json.dumps({"batch": results}), flush=True)
            return_to = str(payload.get("return_to", ""))
            if return_to.startswith(RETURN_ORIGIN):
                self.send_response(303)
                self.send_header("Location", return_to)
                self.send_header("Content-Length", "0")
                self.end_headers()
            else:
                self.send_text(200, json.dumps(results, indent=2))
            if state["batches"] >= state["max_batches"] > 0:
                state["done"] = True

    return Handler


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("out_dir", type=Path, help="Directory to save icons in")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument(
        "--batches",
        type=int,
        default=0,
        help="Stop after this many batches (default 0: run until the idle timeout)",
    )
    parser.add_argument(
        "--idle-timeout",
        type=int,
        default=900,
        help="Stop after this many seconds without a batch (default 900)",
    )
    args = parser.parse_args()

    out_dir = args.out_dir.expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    token = secrets.token_urlsafe(16)
    state = {"batches": 0, "max_batches": args.batches, "done": False, "last": time.time()}
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), make_handler(out_dir, token, state))
    except OSError as error:
        sys.exit(f"Could not listen on 127.0.0.1:{args.port}: {error}. Try another --port.")

    print(json.dumps({"receiver": f"http://localhost:{args.port}/{token}/", "out_dir": str(out_dir)}), flush=True)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    while not state["done"] and time.time() - state["last"] < args.idle_timeout:
        time.sleep(0.5)
    time.sleep(1)
    server.shutdown()
    print(json.dumps({"stopped": True, "batches": state["batches"]}), flush=True)


if __name__ == "__main__":
    main()
