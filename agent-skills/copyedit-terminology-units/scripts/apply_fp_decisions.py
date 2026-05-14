#!/usr/bin/env python3
"""
Apply per-issue false-positive decisions to a merged issues JSON file.

Decisions directory:
- contains one JSON file per issue, with at least:
  - uid
  - decision: keep or dismiss
  - reason
  - optional issue_patch object to patch fields on the issue

Output:
- JSON object with meta and issues (with status kept or dismissed).
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Tuple


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


def _load_decisions(decisions_dir: Path) -> Dict[str, Dict[str, Any]]:
    decisions: Dict[str, Dict[str, Any]] = {}
    if not decisions_dir.exists():
        return decisions

    for p in sorted(decisions_dir.glob("*.json")):
        try:
            d = json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            continue
        if not isinstance(d, dict):
            continue
        uid = d.get("uid")
        if not uid:
            continue
        decisions[str(uid)] = d
    return decisions


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--issues", required=True, help="Merged issues JSON path")
    parser.add_argument("--decisions_dir", required=True, help="Directory of decision JSON files")
    parser.add_argument("--out", required=True, help="Output JSON path")
    args = parser.parse_args()

    issues_path = Path(args.issues)
    decisions_dir = Path(args.decisions_dir)
    out_path = Path(args.out)

    meta, issues = _load_issues(issues_path)
    decisions = _load_decisions(decisions_dir)

    for issue in issues:
        uid = str(issue.get("uid") or "")
        d = decisions.get(uid)
        if not d:
            issue["status"] = "kept"
            continue

        decision = (d.get("decision") or "keep").strip().lower()
        reason = (d.get("reason") or "").strip()

        if decision == "dismiss":
            issue["status"] = "dismissed"
            if reason:
                issue["dismiss_reason"] = reason
            continue

        # keep
        issue["status"] = "kept"
        if reason:
            issue["keep_reason"] = reason

        patch = d.get("issue_patch")
        if isinstance(patch, dict):
            for k, v in patch.items():
                # Avoid stomping uid and mode unless explicitly requested
                if k in {"uid"}:
                    continue
                issue[k] = v

    meta = dict(meta or {})
    meta["filtered_at"] = datetime.now().isoformat(timespec="seconds")
    meta["decisions_dir"] = str(decisions_dir)

    out_obj = {"meta": meta, "issues": issues}
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(out_obj, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
