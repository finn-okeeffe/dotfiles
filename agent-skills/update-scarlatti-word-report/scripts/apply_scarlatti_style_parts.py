#!/usr/bin/env python3
import argparse
import io
import os
import sys
import tempfile
import zipfile
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PARTS = ["word/styles.xml", "word/theme/theme1.xml", "word/fontTable.xml", "word/numbering.xml"]


def main():
    ap = argparse.ArgumentParser(description="Apply bundled Scarlatti style/theme parts to a versioned DOCX.")
    ap.add_argument("input", type=Path)
    ap.add_argument("--asset", type=Path, default=Path(__file__).resolve().parents[1] / "assets" / "scarlatti-style-parts.zip")
    ap.add_argument("--confirm-style-replacement", action="store_true", required=True)
    args = ap.parse_args()
    with zipfile.ZipFile(args.input) as zin:
        files = {n: zin.read(n) for n in zin.namelist()}
    with zipfile.ZipFile(args.asset) as styles:
        for part in PARTS:
            if part in styles.namelist():
                files[part] = styles.read(part)
    fd, tmp = tempfile.mkstemp(suffix=args.input.suffix, dir=args.input.parent)
    os.close(fd)
    Path(tmp).unlink(missing_ok=True)
    try:
        with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
            for name, blob in files.items():
                zout.writestr(name, blob)
        Path(tmp).replace(args.input)
    finally:
        Path(tmp).unlink(missing_ok=True)
    print(args.input)


if __name__ == "__main__":
    main()
