#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///

from __future__ import annotations

import argparse
import hashlib
import os
import re
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class MermaidBlock:
    fence: str
    info: str
    source: str


def _minify_mermaid(source: str) -> str:
    # Keep it readable but compact: collapse whitespace and strip comment-only lines.
    lines: list[str] = []
    for line in source.splitlines():
        s = line.strip()
        if not s:
            continue
        # Mermaid supports %% comments
        if s.startswith("%%"):
            continue
        lines.append(s)
    compact = " ".join(lines)
    compact = re.sub(r"\s+", " ", compact).strip()
    return compact


def _truncate(s: str, max_len: int) -> str:
    if max_len <= 0:
        return ""
    if len(s) <= max_len:
        return s
    if max_len == 1:
        return "…"
    return s[: max_len - 1] + "…"


def _render_mermaid_png(kroki_url: str, mermaid_source: str) -> bytes:
    url = kroki_url.rstrip("/") + "/mermaid/png"
    req = urllib.request.Request(
        url,
        data=mermaid_source.encode("utf-8"),
        headers={
            "Content-Type": "text/plain; charset=utf-8",
            "Accept": "image/png",
            "User-Agent": "make-docx-file/render_mermaid.py",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        body = ""
        try:
            body = e.read().decode("utf-8", errors="replace")
        except Exception:
            pass
        raise RuntimeError(f"Kroki HTTP {e.code} from {url}: {body}".strip()) from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"Failed to reach Kroki at {url}: {e}") from e


def _find_fenced_blocks(lines: list[str]) -> Iterable[tuple[int, int, MermaidBlock]]:
    """
    Yields (start_idx, end_idx_exclusive, MermaidBlock) for fenced mermaid blocks.
    Supports backtick fences of length >= 3. The closing fence must match the opening.
    """
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^(\s*)(`{3,})(\s*)(.*)\s*$", line)
        if not m:
            i += 1
            continue

        indent, fence, _, info = m.groups()
        info_stripped = info.strip()
        # Common form is ```mermaid
        if not info_stripped.lower().startswith("mermaid"):
            i += 1
            continue

        start = i
        i += 1
        block_lines: list[str] = []
        while i < len(lines):
            if re.match(rf"^{re.escape(indent)}{re.escape(fence)}\s*$", lines[i]):
                end = i + 1
                source = "\n".join(block_lines).rstrip() + "\n"
                yield (start, end, MermaidBlock(fence=fence, info=info_stripped, source=source))
                break
            block_lines.append(lines[i])
            i += 1
        else:
            # Unclosed fence; stop scanning to avoid mangling the document.
            return

        i = end


def _replace_range(lines: list[str], start: int, end: int, replacement: list[str]) -> list[str]:
    return lines[:start] + replacement + lines[end:]


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(
        description="Render ```mermaid fenced blocks via Kroki and rewrite markdown to embed PNGs."
    )
    p.add_argument("input", help="Input markdown file (contains ```mermaid blocks).")
    p.add_argument(
        "--output",
        help="Output markdown file (default: <input>.rendered.md next to input).",
        default=None,
    )
    p.add_argument(
        "--kroki-url",
        default=os.environ.get("KROKI_URL", "http://localhost:8000"),
        help='Kroki base URL (default: "http://localhost:8000"; env: KROKI_URL).',
    )
    p.add_argument(
        "--out-dir",
        default="generated/diagrams",
        help='Directory to write generated images (default: "generated/diagrams").',
    )
    p.add_argument(
        "--caption-max",
        type=int,
        default=220,
        help="Max caption length for embedded Mermaid source (default: 220).",
    )
    args = p.parse_args(argv)

    input_path = Path(args.input)
    if not input_path.exists():
        raise SystemExit(f"Input file not found: {input_path}")

    if args.output is None:
        output_path = input_path.with_suffix(".rendered.md")
    else:
        output_path = Path(args.output)

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    raw = input_path.read_text(encoding="utf-8")
    lines = raw.splitlines()
    # Preserve trailing newline behavior.
    had_trailing_newline = raw.endswith("\n")

    blocks = list(_find_fenced_blocks(lines))
    if not blocks:
        # Still write the output so downstream steps are uniform.
        output_path.write_text(raw, encoding="utf-8")
        return 0

    # Apply replacements from bottom to top so indices remain valid.
    for start, end, block in reversed(blocks):
        mermaid_source = block.source
        digest = hashlib.sha256(mermaid_source.encode("utf-8")).hexdigest()[:10]
        img_rel = Path(out_dir) / f"mermaid-{digest}.png"

        png_bytes = _render_mermaid_png(args.kroki_url, mermaid_source)
        img_rel.write_bytes(png_bytes)

        compact = _minify_mermaid(mermaid_source)
        caption = _truncate(f"Mermaid: {compact}", args.caption_max)

        # Standalone image paragraph => pandoc implicit_figures turns this into a figure with caption.
        replacement = [
            f"![{caption}]({img_rel.as_posix()})",
            "",
            "<!-- mermaid-source:",
            "```mermaid",
            mermaid_source.rstrip("\n"),
            "```",
            "-->",
        ]
        lines = _replace_range(lines, start, end, replacement)

    out_text = "\n".join(lines) + ("\n" if had_trailing_newline else "")
    output_path.write_text(out_text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

