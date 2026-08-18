#!/usr/bin/env python3
import argparse
import re
import shutil
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def next_path(src: Path) -> Path:
    stem = src.stem
    m = re.search(r"(?i)(.*?)(?:[ _-])v(\d+)(?:_(\d+))?$", stem)
    if not m:
        return src.with_name(f"{stem} v2{src.suffix}")
    prefix, major, minor = m.group(1).rstrip(), int(m.group(2)), m.group(3)
    version = f"v{major + 1}" if minor is None else f"v{major}_{int(minor) + 1}"
    return src.with_name(f"{prefix} {version}{src.suffix}")


def main():
    ap = argparse.ArgumentParser(description="Create a new versioned DOCX without overwriting files.")
    ap.add_argument("input", type=Path)
    ap.add_argument("--output", type=Path)
    args = ap.parse_args()
    src = args.input.resolve()
    if src.suffix.lower() not in {".docx", ".docm"} or not src.is_file():
        raise SystemExit(f"Input must be an existing DOCX/DOCM: {src}")
    out = (args.output or next_path(src)).resolve()
    if out == src:
        raise SystemExit("Refusing to overwrite the source document")
    if out.exists():
        raise SystemExit(f"Refusing to overwrite existing output: {out}")
    out.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, out)
    print(out)


if __name__ == "__main__":
    main()
