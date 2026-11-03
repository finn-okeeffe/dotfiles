# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Build a self-contained Scarlatti HTML report from a content-only HTML file.

Usage:
    uv run build.py my-report.content.html            # writes my-report.html
    uv run build.py notes.html -o notes-report.html

The content file holds only the report body (title block, sections, figures).
This script wraps it in the Scarlatti template, inlines the stylesheet, script
and logo, embeds local images as data URIs, and prints warnings for common
authoring mistakes. Standard library only.
"""

from __future__ import annotations

import argparse
import base64
import html
import mimetypes
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
ASSETS = SKILL_DIR / "assets"
KATEX = ASSETS / "katex"
CHART_TYPES = {"column", "bar", "stacked-column", "stacked-bar", "line", "donut"}
MATH_DELIMITERS = re.compile(r"\\\(|\\\[|\$\$")


class Checker(HTMLParser):
    """Collects facts about the content so authoring mistakes can be reported."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.h1: list[str] = []
        self.in_h1 = False
        self.page_tags: list[str] = []
        self.styles = 0
        self.warnings: list[str] = []
        self.figure_stack: list[dict] = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        line = self.getpos()[0]
        if tag in {"html", "head", "body"}:
            self.page_tags.append(tag)
        if tag in {"style", "script", "link"}:
            self.styles += 1
            self.warnings.append(f"line {line}: <{tag}> found; the template supplies all styling and scripts.")
        if tag == "h1":
            self.in_h1 = True
            self.h1.append("")
        if tag == "img" and not (a.get("alt") or "").strip():
            self.warnings.append(f"line {line}: <img src=\"{a.get('src', '')}\"> has no alt text.")
        if tag == "figure":
            classes = (a.get("class") or "").split()
            fig = {"chart": "chart" in classes, "table": False, "caption": False, "line": line}
            if fig["chart"]:
                ctype = (a.get("data-type") or "column").strip().lower()
                if ctype not in CHART_TYPES:
                    self.warnings.append(f"line {line}: unknown chart type \"{ctype}\"; use one of {', '.join(sorted(CHART_TYPES))}.")
            self.figure_stack.append(fig)
        if self.figure_stack:
            if tag == "table":
                self.figure_stack[-1]["table"] = True
            if tag == "figcaption":
                self.figure_stack[-1]["caption"] = True

    def handle_endtag(self, tag):
        if tag == "h1":
            self.in_h1 = False
        if tag == "figure" and self.figure_stack:
            fig = self.figure_stack.pop()
            if fig["chart"] and not fig["table"]:
                self.warnings.append(f"line {fig['line']}: chart figure has no <table> with its data.")
            if not fig["caption"]:
                self.warnings.append(f"line {fig['line']}: figure has no <figcaption>.")

    def handle_data(self, data):
        if self.in_h1:
            self.h1[-1] += data


def data_uri(path: Path) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    if path.suffix.lower() == ".svg":
        mime = "image/svg+xml"
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode('ascii')}"


def katex_blocks() -> tuple[str, str]:
    """KaTeX stylesheet with its WOFF2 fonts embedded, and its two scripts."""
    css = (KATEX / "katex.min.css").read_text(encoding="utf-8")

    def font(match: re.Match) -> str:
        return f'src:url({data_uri(KATEX / "fonts" / (match.group(1) + ".woff2"))}) format("woff2")'

    # keep only the WOFF2 source of each @font-face, as a data URI
    css = re.sub(r'src:url\(fonts/([\w-]+)\.woff2\) format\("woff2"\)(?:,url\([^)]*\) format\("[^"]*"\))*', font, css)
    js = "\n".join((KATEX / name).read_text(encoding="utf-8") for name in ("katex.min.js", "auto-render.min.js"))
    return f"<style>\n{css}\n</style>", f"<script>\n{js}\n</script>"


def inline_images(content: str, base: Path, warnings: list[str]) -> str:
    def swap(match: re.Match) -> str:
        quote, src = match.group(2), match.group(3)
        if re.match(r"^(data:|https?:|//)", src):
            return match.group(0)
        target = (base / html.unescape(src)).resolve()
        if not target.is_file():
            warnings.append(f"image not found: {src} (looked for {target})")
            return match.group(0)
        return f"{match.group(1)}{quote}{data_uri(target)}{quote}"

    return re.sub(r"(<img\b[^>]*?\bsrc\s*=\s*)([\"'])(.*?)\2", swap, content, flags=re.I | re.S)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("content", type=Path, help="content-only HTML file")
    parser.add_argument("-o", "--output", type=Path, help="output HTML file")
    args = parser.parse_args()

    src: Path = args.content
    if not src.is_file():
        print(f"error: {src} does not exist", file=sys.stderr)
        return 1

    out: Path | None = args.output
    if out is None:
        if src.name.endswith(".content.html"):
            out = src.with_name(src.name[: -len(".content.html")] + ".html")
        else:
            print("error: name the content file <name>.content.html or pass -o <output.html>", file=sys.stderr)
            return 1
    if out.resolve() == src.resolve():
        print("error: the output would overwrite the content file", file=sys.stderr)
        return 1

    content = src.read_text(encoding="utf-8")
    checker = Checker()
    checker.feed(content)
    checker.close()
    warnings = checker.warnings

    if checker.page_tags:
        print(f"error: the content file contains <{checker.page_tags[0]}>. Write only the report body; "
              "the template supplies the page.", file=sys.stderr)
        return 1
    if not checker.h1:
        warnings.append("no <h1> found; the report has no title.")
    elif len(checker.h1) > 1:
        warnings.append(f"{len(checker.h1)} <h1> elements found; use one title and <h2> for sections.")

    title = re.sub(r"\s+", " ", checker.h1[0]).strip() if checker.h1 else "Scarlatti report"
    content = inline_images(content, src.parent, warnings)

    page = (ASSETS / "template.html").read_text(encoding="utf-8")
    page = page.replace("{{TITLE}}", html.escape(title))
    katex_css, katex_js = katex_blocks() if MATH_DELIMITERS.search(content) else ("", "")
    page = page.replace("{{KATEX_CSS}}", katex_css)
    page = page.replace("{{KATEX_JS}}", katex_js)
    page = page.replace("{{LOGO}}", data_uri(ASSETS / "scarlatti-primary-tagline-right.png"))
    page = page.replace("{{CSS}}", (ASSETS / "report.css").read_text(encoding="utf-8"))
    page = page.replace("{{JS}}", (ASSETS / "report.js").read_text(encoding="utf-8"))
    page = page.replace("{{CONTENT}}", content)

    out.write_text(page, encoding="utf-8")
    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)
    print(f"wrote {out} ({out.stat().st_size / 1024:.0f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
