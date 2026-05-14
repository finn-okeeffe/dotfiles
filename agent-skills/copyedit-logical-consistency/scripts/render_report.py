#!/usr/bin/env python3
"""
Render a markdown copy-edit report from a filtered issues JSON file.

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

MODE_LABELS = {
    "general": "General copy editing",
    "advanced_style": "Advanced style refinement",
    "logical_consistency": "Logical consistency",
    "terminology_units": "Terminology and units",
    "unknown": "Other",
}

SEVERITY_ORDER = {"critical": 4, "high": 3, "medium": 2, "low": 1}


def _sanitize(text: Any) -> str:
    s = str(text or "")
    for bad, repl in FORBIDDEN_DASHES.items():
        s = s.replace(bad, repl)
    # Keep report one-line friendly in fields
    s = s.replace("\r", " ").replace("\n", " ")
    return s


def _load(path: Path) -> Tuple[Dict[str, Any], List[Dict[str, Any]]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, list):
        return {}, [dict(x) for x in data if isinstance(x, dict)]
    if isinstance(data, dict):
        return dict(data.get("meta") or {}), [dict(x) for x in (data.get("issues") or []) if isinstance(x, dict)]
    raise ValueError("Unsupported JSON shape: expected list or object")


def _severity_value(sev: str) -> int:
    return SEVERITY_ORDER.get((sev or "").strip().lower(), 0)


def _bool_label(v: Any) -> str:
    return "Yes" if bool(v) else "No"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--issues", required=True, help="Filtered issues JSON path")
    parser.add_argument("--out", required=True, help="Output markdown path")
    args = parser.parse_args()

    issues_path = Path(args.issues)
    out_path = Path(args.out)

    meta, issues = _load(issues_path)

    # Sanitise fields defensively
    for i in issues:
        for k in ["uid", "mode", "severity", "location", "excerpt", "problem", "suggestion", "status", "dismiss_reason", "keep_reason", "confidence"]:
            if k in i:
                i[k] = _sanitize(i[k])

    kept = [i for i in issues if (i.get("status") or "").lower() != "dismissed"]
    dismissed = [i for i in issues if (i.get("status") or "").lower() == "dismissed"]

    # Counts
    def count_by(items: List[Dict[str, Any]], key: str) -> Dict[str, int]:
        out: Dict[str, int] = {}
        for it in items:
            v = (it.get(key) or "unknown").strip().lower()
            out[v] = out.get(v, 0) + 1
        return out

    kept_by_sev = count_by(kept, "severity")
    dismissed_by_sev = count_by(dismissed, "severity")

    # Sort kept issues
    kept.sort(
        key=lambda i: (
            -_severity_value(i.get("severity", "")),
            str(i.get("mode") or ""),
            str(i.get("location") or ""),
            str(i.get("uid") or ""),
        )
    )
    dismissed.sort(
        key=lambda i: (
            -_severity_value(i.get("severity", "")),
            str(i.get("mode") or ""),
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
    lines.append("Kept by severity:")
    for sev in ["critical", "high", "medium", "low"]:
        lines.append(f"- {sev}: {kept_by_sev.get(sev, 0)}")
    lines.append("")
    if dismissed:
        lines.append("Dismissed by severity:")
        for sev in ["critical", "high", "medium", "low"]:
            lines.append(f"- {sev}: {dismissed_by_sev.get(sev, 0)}")
        lines.append("")

    lines.append("## Kept issues")
    if not kept:
        lines.append("")
        lines.append("No issues were kept after filtering.")
    else:
        current_sev = None
        comment_n = 1
        for issue in kept:
            sev = (issue.get("severity") or "unknown").lower()
            if sev != current_sev:
                current_sev = sev
                lines.append("")
                lines.append(f"### {sev.capitalize()}")
            mode = (issue.get("mode") or "unknown").lower()
            mode_label = MODE_LABELS.get(mode, mode)
            uid = issue.get("uid") or f"ISSUE-{comment_n:04d}"
            confidence = issue.get("confidence") or "medium"
            discretionary = _bool_label(issue.get("discretionary", False))
            lines.append("")
            lines.append(f"- Comment {comment_n} ({uid})")
            lines.append(f"  - Mode: {mode_label}")
            lines.append(f"  - Severity: {sev}")
            lines.append(f"  - Discretionary: {discretionary}")
            lines.append(f"  - Confidence: {confidence}")
            loc = issue.get("location") or ""
            if loc:
                lines.append(f"  - Location: {loc}")
            excerpt = issue.get("excerpt") or ""
            if excerpt:
                lines.append(f"  - Excerpt: \"{excerpt}\"")
            problem = issue.get("problem") or ""
            if problem:
                lines.append(f"  - Issue: {problem}")
            suggestion = issue.get("suggestion") or ""
            if suggestion:
                lines.append(f"  - Suggestion: {suggestion}")
            # Optional logical consistency support rating
            if issue.get("support_rating"):
                lines.append(f"  - Support rating: {issue.get('support_rating')}")
            comment_n += 1

    if dismissed:
        lines.append("")
        lines.append("## Dismissed suggestions")
        lines.append("These were dismissed as false positives, duplicates, or too nitpicky for the final report.")
        comment_n = 1
        for issue in dismissed:
            sev = (issue.get("severity") or "unknown").lower()
            mode = (issue.get("mode") or "unknown").lower()
            mode_label = MODE_LABELS.get(mode, mode)
            uid = issue.get("uid") or f"ISSUE-D-{comment_n:04d}"
            lines.append("")
            lines.append(f"- {uid} ({mode_label}, {sev})")
            reason = issue.get("dismiss_reason") or ""
            if reason:
                lines.append(f"  - Reason dismissed: {reason}")
            loc = issue.get("location") or ""
            if loc:
                lines.append(f"  - Location: {loc}")
            excerpt = issue.get("excerpt") or ""
            if excerpt:
                lines.append(f"  - Excerpt: \"{excerpt}\"")
            comment_n += 1

    # Final safety check: ensure forbidden dash characters are not present
    report = "\n".join(lines).replace("\r\n", "\n").replace("\r", "\n")
    for bad in FORBIDDEN_DASHES.keys():
        report = report.replace(bad, FORBIDDEN_DASHES[bad])

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(report + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
