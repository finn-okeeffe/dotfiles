#!/usr/bin/env python3
"""Extract kept issues from copyedit feedback markdown into ordered JSON."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path


COMMENT_RE = re.compile(r"^- Comment\s+(\d+)\s+\(([^)]+)\)")
FIELD_RE = re.compile(r"^\s*-\s+([^:]+):\s*(.*)$")


@dataclass
class Issue:
    index: int
    comment_number: int
    issue_id: str
    severity_group: str
    fields: dict[str, str] = field(default_factory=dict)
    full_feedback: str = ""

    def to_dict(self) -> dict[str, object]:
        out: dict[str, object] = {
            "index": self.index,
            "comment_number": self.comment_number,
            "issue_id": self.issue_id,
            "severity_group": self.severity_group,
            "full_feedback": self.full_feedback,
        }
        out.update(self.fields)
        return out


def normalize_key(raw: str) -> str:
    return (
        raw.strip()
        .lower()
        .replace(" ", "_")
        .replace("-", "_")
        .replace("/", "_")
        .replace("(", "")
        .replace(")", "")
    )


def parse_kept_issues(text: str) -> list[dict[str, object]]:
    lines = text.splitlines()

    start = None
    for i, line in enumerate(lines):
        if line.strip().lower() == "## kept issues":
            start = i + 1
            break
    if start is None:
        raise ValueError("Could not find '## Kept issues' section.")

    end = len(lines)
    for i in range(start, len(lines)):
        if lines[i].strip().lower().startswith("## dismissed suggestions"):
            end = i
            break

    issues: list[Issue] = []
    severity_group = ""
    i = start

    while i < end:
        line = lines[i]
        if line.startswith("### "):
            severity_group = line.removeprefix("### ").strip()
            i += 1
            continue

        m = COMMENT_RE.match(line)
        if not m:
            i += 1
            continue

        comment_number = int(m.group(1))
        issue_id = m.group(2).strip()
        block_lines = [line]
        fields: dict[str, str] = {}
        i += 1

        while i < end:
            nxt = lines[i]
            if COMMENT_RE.match(nxt) or nxt.startswith("### "):
                break

            block_lines.append(nxt)
            fm = FIELD_RE.match(nxt)
            if fm:
                key = normalize_key(fm.group(1))
                fields[key] = fm.group(2).strip()
            i += 1

        issue = Issue(
            index=len(issues) + 1,
            comment_number=comment_number,
            issue_id=issue_id,
            severity_group=severity_group or fields.get("severity", ""),
            fields=fields,
            full_feedback="\n".join(block_lines).strip(),
        )
        issues.append(issue)

    return [x.to_dict() for x in issues]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract kept issues from copyedit feedback markdown."
    )
    parser.add_argument(
        "--input",
        required=True,
        help="Path to feedback markdown file, e.g. copyedit_feedback.md",
    )
    parser.add_argument(
        "--output",
        help="Output JSON path. If omitted, print JSON to stdout.",
    )
    parser.add_argument(
        "--compact",
        action="store_true",
        help="Write compact JSON without indentation.",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Input file not found: {input_path}", file=sys.stderr)
        return 2

    try:
        content = input_path.read_text(encoding="utf-8")
        issues = parse_kept_issues(content)
    except Exception as exc:
        print(f"Failed to parse feedback file: {exc}", file=sys.stderr)
        return 1

    if not issues:
        print("No kept issues found.", file=sys.stderr)
        return 3

    payload = json.dumps(issues, ensure_ascii=True, indent=None if args.compact else 2)

    if args.output:
        out_path = Path(args.output)
        out_path.write_text(payload + "\n", encoding="utf-8")
    else:
        print(payload)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
