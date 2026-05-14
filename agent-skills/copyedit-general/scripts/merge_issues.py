#!/usr/bin/env python3
"""
Merge and de-duplicate issue JSON files produced by copy-edit mode skills.

This script uses only the Python standard library.

Input files:
- Each file should be either a JSON array of issues, or an object with an "issues" array.

Output:
- A JSON object with:
  - meta: basic metadata
  - issues: merged, de-duplicated, sorted issues
"""
from __future__ import annotations

import argparse
import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Tuple


SEVERITY_ORDER = {
    "critical": 4,
    "high": 3,
    "medium": 2,
    "low": 1,
}


def _normalise(text: str) -> str:
    text = (text or "").strip().lower()
    text = re.sub(r"\s+", " ", text)
    return text


def _load_issues(path: Path) -> Tuple[Dict[str, Any], List[Dict[str, Any]]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, list):
        return {}, [dict(x) for x in data if isinstance(x, dict)]
    if isinstance(data, dict):
        meta = dict(data.get("meta") or {})
        issues_raw = data.get("issues") or []
        if not isinstance(issues_raw, list):
            raise ValueError(f'"issues" must be a list in {path}')
        return meta, [dict(x) for x in issues_raw if isinstance(x, dict)]
    raise ValueError(f"Unsupported JSON shape in {path}: expected list or object")


def _severity_value(sev: str) -> int:
    return SEVERITY_ORDER.get((sev or "").strip().lower(), 0)


def _best_of(a: Dict[str, Any], b: Dict[str, Any]) -> Dict[str, Any]:
    """
    Choose the better issue between a and b for the same location+excerpt key.
    Preference order: higher severity, then higher confidence (high>medium>low), then keep a.
    """
    if _severity_value(b.get("severity", "")) > _severity_value(a.get("severity", "")):
        return b
    if _severity_value(b.get("severity", "")) < _severity_value(a.get("severity", "")):
        return a

    conf_order = {"high": 3, "medium": 2, "low": 1}
    a_conf = conf_order.get((a.get("confidence") or "").lower(), 0)
    b_conf = conf_order.get((b.get("confidence") or "").lower(), 0)
    if b_conf > a_conf:
        return b
    return a


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, help="Output JSON path")
    parser.add_argument("inputs", nargs="+", help="Input issue JSON paths")
    args = parser.parse_args()

    out_path = Path(args.out)
    input_paths = [Path(p) for p in args.inputs]

    merged_meta: Dict[str, Any] = {
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "source_issue_files": [str(p) for p in input_paths],
    }

    seen: Dict[Tuple[str, str], Dict[str, Any]] = {}
    uid_counter = 1

    for p in input_paths:
        _, issues = _load_issues(p)
        for issue in issues:
            # Skip issues that were already dismissed by an upstream filter.
            status = str(issue.get("status") or "").strip().lower()
            if status == "dismissed":
                continue

            # Remove any upstream decision metadata before merging.
            issue.pop("dismiss_reason", None)
            issue.pop("keep_reason", None)

            # Normalise required-ish fields and apply defaults
            issue.setdefault("mode", "unknown")
            issue.setdefault("severity", "medium")
            issue.setdefault("location", "")
            issue.setdefault("excerpt", "")
            issue.setdefault("problem", "")
            issue.setdefault("suggestion", "")
            issue.setdefault("discretionary", False)
            issue.setdefault("confidence", "medium")

            # Clean excerpt for keying and output
            excerpt = str(issue.get("excerpt") or "")
            excerpt = excerpt.replace("\n", " ").replace("\r", " ")
            excerpt = re.sub(r"\s+", " ", excerpt).strip()
            issue["excerpt"] = excerpt

            loc = str(issue.get("location") or "").strip()
            key = (_normalise(loc), _normalise(excerpt))

            # Always treat merged issues as candidates (final filtering happens downstream).
            issue["status"] = "candidate"

            if key in seen:
                chosen = _best_of(seen[key], issue)
                if chosen is issue:
                    # Keep uid from the issue we are replacing so references remain stable
                    issue["uid"] = seen[key].get("uid")
                    issue.setdefault("also_reported_in", seen[key].get("also_reported_in", []))
                    seen[key] = issue
                else:
                    # Track that this was also reported elsewhere
                    existing = seen[key]
                    existing.setdefault("also_reported_in", [])
                    mode = issue.get("mode")
                    if mode and mode not in existing["also_reported_in"]:
                        existing["also_reported_in"].append(mode)
                continue

            if not issue.get("uid"):
                issue["uid"] = f"ISSUE-{uid_counter:04d}"
                uid_counter += 1

            seen[key] = issue

    merged_issues = list(seen.values())
    merged_issues.sort(
        key=lambda i: (
            -_severity_value(i.get("severity", "")),
            str(i.get("mode") or ""),
            str(i.get("location") or ""),
            str(i.get("uid") or ""),
        )
    )

    out_obj = {"meta": merged_meta, "issues": merged_issues}
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(out_obj, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
