#!/usr/bin/env python3
"""
Render a markdown repetition de-duplication report from a filtered issues JSON file.

Input:
- JSON array of issues, or an object with "issues" and optional "meta".

Output:
- Markdown report written to --out
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Tuple


FORBIDDEN_DASHES = {
    "\u2013": "-",  # en dash
    "\u2014": "-",  # em dash
}

SEVERITY_ORDER = {"critical": 4, "high": 3, "medium": 2, "low": 1}
ALLOWED_ACTIONS = {"keep": "Keep", "cut": "Cut", "merge": "Merge"}


def _sanitize(text: Any) -> str:
    s = str(text or "")
    for bad, repl in FORBIDDEN_DASHES.items():
        s = s.replace(bad, repl)
    s = s.replace("\r", " ").replace("\n", " ")
    return " ".join(s.split())


def _load(path: Path) -> Tuple[Dict[str, Any], List[Dict[str, Any]]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, list):
        return {}, [dict(x) for x in data if isinstance(x, dict)]
    if isinstance(data, dict):
        return dict(data.get("meta") or {}), [dict(x) for x in (data.get("issues") or []) if isinstance(x, dict)]
    raise ValueError("Unsupported JSON shape: expected list or object")


def _severity_value(sev: str) -> int:
    return SEVERITY_ORDER.get((sev or "").strip().lower(), 0)


def _clip_words(text: str, limit: int = 15) -> str:
    words = _sanitize(text).split()
    if len(words) <= limit:
        return " ".join(words)
    return " ".join(words[:limit]) + " ..."


def _action(issue: Dict[str, Any]) -> str:
    action = str(issue.get("dedup_action") or "").strip().lower()
    return ALLOWED_ACTIONS.get(action, "Merge")


def _reason(issue: Dict[str, Any]) -> str:
    keep_reason = _sanitize(issue.get("keep_reason") or "")
    if keep_reason:
        return keep_reason
    problem = _sanitize(issue.get("problem") or "")
    if not problem:
        return "This repeats an earlier proposition without adding material detail."
    return problem


def _merged_sentence(issue: Dict[str, Any]) -> str:
    merged = _sanitize(issue.get("merged_sentence") or "")
    if merged:
        return merged
    suggestion = _sanitize(issue.get("suggestion") or "")
    if suggestion:
        return suggestion
    return ""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--issues", required=True, help="Filtered issues JSON path")
    parser.add_argument("--out", required=True, help="Output markdown path")
    args = parser.parse_args()

    issues_path = Path(args.issues)
    out_path = Path(args.out)

    meta, issues = _load(issues_path)

    for issue in issues:
        for key in [
            "uid",
            "mode",
            "severity",
            "location",
            "excerpt",
            "problem",
            "suggestion",
            "status",
            "dismiss_reason",
            "keep_reason",
            "confidence",
            "earlier_excerpt",
            "earlier_location",
            "later_excerpt",
            "later_location",
            "dedup_action",
            "merged_sentence",
        ]:
            if key in issue:
                issue[key] = _sanitize(issue[key])

    kept = [i for i in issues if (i.get("status") or "").lower() != "dismissed"]
    dismissed = [i for i in issues if (i.get("status") or "").lower() == "dismissed"]

    kept.sort(
        key=lambda i: (
            -_severity_value(i.get("severity", "")),
            str(i.get("location") or ""),
            str(i.get("uid") or ""),
        )
    )
    dismissed.sort(
        key=lambda i: (
            -_severity_value(i.get("severity", "")),
            str(i.get("location") or ""),
            str(i.get("uid") or ""),
        )
    )

    created_at = meta.get("created_at") or datetime.now().isoformat(timespec="seconds")
    source_files = meta.get("source_issue_files") or []

    lines: List[str] = []
    lines.append("# Copy-edit feedback")
    lines.append("")
    lines.append(f"Generated: {created_at}")
    if source_files:
        lines.append("Source issue files:")
        for p in source_files:
            lines.append(f"- {_sanitize(p)}")
        lines.append("")
    lines.append("Fact-checking: no external sources used (unless the user explicitly requested otherwise).")
    lines.append("Language: New Zealand English.")
    lines.append("")
    lines.append("## Summary")
    lines.append(f"- Issues kept: {len(kept)}")
    lines.append(f"- Issues dismissed: {len(dismissed)}")
    lines.append("")

    lines.append("## Kept issues")
    if not kept:
        lines.append("")
        lines.append("No issues were kept after filtering.")
    else:
        current_sev = None
        comment_n = 1
        for issue in kept:
            severity = (issue.get("severity") or "unknown").lower()
            if severity != current_sev:
                current_sev = severity
                lines.append("")
                lines.append(f"### {severity.capitalize()}")

            uid = issue.get("uid") or f"ISSUE-{comment_n:04d}"
            confidence = issue.get("confidence") or "medium"
            action = _action(issue)
            reason = _reason(issue)
            merged_sentence = _merged_sentence(issue)

            earlier_excerpt = _clip_words(issue.get("earlier_excerpt") or issue.get("excerpt") or "")
            later_excerpt = _clip_words(issue.get("later_excerpt") or issue.get("excerpt") or "")
            earlier_location = issue.get("earlier_location") or issue.get("location") or ""
            later_location = issue.get("later_location") or issue.get("location") or ""

            lines.append("")
            lines.append(f"- Comment {comment_n} ({uid})")
            lines.append("  - Mode: Repetition de-duplication")
            lines.append(f"  - Severity: {severity}")
            lines.append(f"  - Confidence: {confidence}")
            lines.append(f"  - Earlier: \"{earlier_excerpt}\" [Location: {earlier_location}]")
            lines.append(f"  - Later: \"{later_excerpt}\" [Location: {later_location}]")
            lines.append(f"  - Action: {action}.")
            if action == "Merge" and merged_sentence:
                lines.append(f"  - Reason: {reason} If Merge, write: \"{merged_sentence}\"")
            else:
                lines.append(f"  - Reason: {reason}")

            comment_n += 1

    if dismissed:
        lines.append("")
        lines.append("## Dismissed suggestions")
        lines.append("These were dismissed as false positives, duplicates, or too nitpicky for the final report.")
        for issue in dismissed:
            uid = issue.get("uid") or "ISSUE-D"
            sev = (issue.get("severity") or "unknown").lower()
            reason = issue.get("dismiss_reason") or "No reason provided"
            loc = issue.get("location") or ""
            excerpt = _clip_words(issue.get("excerpt") or issue.get("later_excerpt") or "")
            lines.append("")
            lines.append(f"- {uid} ({sev})")
            lines.append(f"  - Reason dismissed: {reason}")
            if loc:
                lines.append(f"  - Location: {loc}")
            if excerpt:
                lines.append(f"  - Excerpt: \"{excerpt}\"")

    report = "\n".join(lines).replace("\r\n", "\n").replace("\r", "\n")
    for bad, repl in FORBIDDEN_DASHES.items():
        report = report.replace(bad, repl)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(report + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
