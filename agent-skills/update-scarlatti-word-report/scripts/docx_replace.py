#!/usr/bin/env python3
import argparse
import json
import os
import sys
import tempfile
import zipfile
from pathlib import Path
from lxml import etree

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
A = "http://schemas.openxmlformats.org/drawingml/2006/main"


def replace_across_nodes(root, old, new):
    nodes = root.xpath(".//w:t|.//a:t", namespaces={"w": W, "a": A})
    full = "".join(n.text or "" for n in nodes)
    starts, pos = [], 0
    while True:
        hit = full.find(old, pos)
        if hit < 0:
            break
        starts.append(hit)
        pos = hit + len(old)
    for start in reversed(starts):
        end, cursor, first = start + len(old), 0, None
        for node in nodes:
            text = node.text or ""
            lo, hi = cursor, cursor + len(text)
            if hi > start and lo < end:
                if first is None:
                    first = node
                    node.text = text[: max(0, start-lo)] + new + (text[max(0, end-lo):] if end <= hi else "")
                else:
                    node.text = text[: max(0, start-lo)] + text[max(0, end-lo):]
            cursor = hi
    return len(starts)


def main():
    ap = argparse.ArgumentParser(description="Exact DOCX text replacement preserving existing runs and package parts.")
    ap.add_argument("input", type=Path)
    ap.add_argument("replacements", type=Path, help='JSON list: [{"old":"...","new":"...","expected":1}]')
    args = ap.parse_args()
    specs = json.loads(args.replacements.read_text(encoding="utf-8"))
    with zipfile.ZipFile(args.input) as zin:
        files = {n: zin.read(n) for n in zin.namelist()}
    root = etree.fromstring(files["word/document.xml"], etree.XMLParser(huge_tree=True))
    counts = {}
    for spec in specs:
        count = replace_across_nodes(root, spec["old"], spec["new"])
        counts[spec["old"]] = count
        if "expected" in spec and count != spec["expected"]:
            raise SystemExit(f"Replacement count mismatch for {spec['old']!r}: expected {spec['expected']}, got {count}")
    files["word/document.xml"] = etree.tostring(root, xml_declaration=True, encoding="UTF-8", standalone="yes")
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
    print(json.dumps(counts, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
