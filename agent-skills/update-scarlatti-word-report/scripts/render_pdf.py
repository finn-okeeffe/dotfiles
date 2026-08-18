#!/usr/bin/env python3
import argparse
import math
import sys
from pathlib import Path
import pypdfium2 as pdfium
from PIL import Image, ImageDraw

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pdf", type=Path)
    ap.add_argument("--output-dir", type=Path, required=True)
    ap.add_argument("--scale", type=float, default=1.5)
    ap.add_argument("--contact-sheet", action="store_true")
    args = ap.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    doc, thumbs = pdfium.PdfDocument(args.pdf), []
    for i, page in enumerate(doc, start=1):
        image = page.render(scale=args.scale).to_pil()
        image.save(args.output_dir / f"page-{i}.png")
        if args.contact_sheet:
            image.thumbnail((260, 370))
            tile = Image.new("RGB", (280, 400), "white")
            tile.paste(image, ((280-image.width)//2, 20))
            ImageDraw.Draw(tile).text((8, 5), str(i), fill="black")
            thumbs.append(tile)
    if thumbs:
        sheet = Image.new("RGB", (1120, 400*math.ceil(len(thumbs)/4)), (220, 220, 220))
        for i, tile in enumerate(thumbs):
            sheet.paste(tile, ((i % 4)*280, (i // 4)*400))
        sheet.save(args.output_dir / "contact-sheet.png")
    print(f"Rendered {len(doc)} pages")


if __name__ == "__main__":
    main()
