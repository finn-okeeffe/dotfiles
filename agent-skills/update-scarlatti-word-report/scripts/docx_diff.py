#!/usr/bin/env python3
import argparse
import hashlib
import json
import sys
import zipfile
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description="List content-level OOXML package differences between two DOCX files.")
    ap.add_argument("before", type=Path)
    ap.add_argument("after", type=Path)
    args = ap.parse_args()
    with zipfile.ZipFile(args.before) as a, zipfile.ZipFile(args.after) as b:
        names = sorted(set(a.namelist()) | set(b.namelist()))
        changed = []
        for n in names:
            if n not in a.namelist() or n not in b.namelist():
                changed.append(n)
            elif hashlib.sha256(a.read(n)).digest() != hashlib.sha256(b.read(n)).digest():
                changed.append(n)
    print(json.dumps({"changed_part_count": len(changed), "changed_parts": changed}, indent=2))


if __name__ == "__main__":
    main()
