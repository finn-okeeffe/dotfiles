#!/usr/bin/env python3
import argparse
import json
import sys
import zipfile
from pathlib import Path
from lxml import etree

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
C = "http://schemas.openxmlformats.org/drawingml/2006/chart"
R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"


def inventory(path: Path):
    with zipfile.ZipFile(path) as z:
        bad = z.testzip()
        root = etree.fromstring(z.read("word/document.xml"), etree.XMLParser(huge_tree=True))
        rels = etree.fromstring(z.read("word/_rels/document.xml.rels"))
        relmap = {r.get("Id"): r.get("Target") for r in rels}
        paragraphs, tables, chart_order = [], [], []
        for p in root.xpath(".//w:body//w:p", namespaces={"w": W}):
            text = "".join(p.xpath(".//w:t/text()", namespaces={"w": W}))
            rids = [x.get(f"{{{R}}}id") for x in p.xpath(".//c:chart", namespaces={"c": C})]
            if text.strip() or rids:
                paragraphs.append(text)
                chart_order.extend(rids)
        for tbl in root.xpath(".//w:body/w:tbl", namespaces={"w": W}):
            rows = []
            for tr in tbl.xpath("./w:tr", namespaces={"w": W}):
                rows.append(["".join(tc.xpath(".//w:t/text()", namespaces={"w": W})) for tc in tr.xpath("./w:tc", namespaces={"w": W})])
            tables.append(rows)
        return {
            "valid_zip": bad is None,
            "bad_zip_member": bad,
            "paragraph_count": len(paragraphs),
            "table_count": len(tables),
            "chart_order": [{"rid": rid, "target": relmap.get(rid)} for rid in chart_order],
            "charts": sorted(n for n in z.namelist() if n.startswith("word/charts/chart") and n.endswith(".xml")),
            "embeddings": sorted(n for n in z.namelist() if n.startswith("word/embeddings/")),
            "media": sorted(n for n in z.namelist() if n.startswith("word/media/")),
            "paragraphs": paragraphs,
            "tables": tables,
        }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input", type=Path)
    ap.add_argument("--output", type=Path)
    ap.add_argument("--validate", action="store_true")
    args = ap.parse_args()
    data = inventory(args.input)
    if args.validate and not data["valid_zip"]:
        raise SystemExit(f"Invalid ZIP member: {data['bad_zip_member']}")
    text = json.dumps(data, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text)


if __name__ == "__main__":
    main()
