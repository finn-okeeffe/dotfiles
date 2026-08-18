---
name: update-scarlatti-word-report
description: Update an existing professional Word report (.docx) as a new version while preserving its wording, layout, Scarlatti styles, colours, charts, embedded workbooks, and document structure. Use for report refreshes driven by spreadsheets or other source data; numeric, table, figure, chart-data, appendix, and tightly scoped content updates; Word package inspection; and final render/diff verification. Always create a new version and never edit the source document in place.
---

# Update Scarlatti Word Report

Update the supplied report surgically. Treat the original DOCX and source data files as read-only.

## Required companion skill

Use the installed `documents` skill for its DOCX render-and-verify requirements. This skill adds Scarlatti-specific workflow, deterministic versioning, and reusable package tools.

## Non-negotiable rules

1. Create the next version before making any edit:
   `uv run python scripts/version_docx.py <input.docx>`.
2. Never overwrite the source DOCX. Refuse an output path that resolves to the input or already exists.
3. Never save source workbooks. Open Excel models read-only and close without saving.
4. Preserve existing prose, styles, geometry, section structure, headers, footers, numbering, fields, relationships, and chart styling unless the user explicitly requests otherwise.
5. Use existing Scarlatti paragraph/table styles. Do not invent colours or restyle the report. Read [references/scarlatti-style.md](references/scarlatti-style.md) before adding content or formatting.
6. Edit the smallest OOXML parts possible. Do not reconstruct a report with `python-docx` when targeted OOXML edits can preserve layout.
7. Render every page after the final edit and inspect it. A structurally valid DOCX is not sufficient.

## Standard workflow

### 1. Establish scope and immutable inputs

- Record source file hashes before opening them.
- Identify excluded sections, permitted text changes, rounding rules, and output naming requirements.
- Create the next version with `scripts/version_docx.py`; edit only that copy.

### 2. Inventory the DOCX

Run:

```powershell
uv run python scripts/docx_inventory.py "report v2.docx" --output inventory.json
```

Map paragraphs, tables, charts, embedded workbooks, images, fields, and captions. Use the inventory to distinguish live Word charts from static images.

### 3. Build an auditable source map

- Map each report number and graph series to an exact source workbook sheet/cell/range or other source location.
- Prefer calculated/displayed values from the native application when formulas, macros, dynamic arrays, data tables, or Monte Carlo results make cached OOXML values unreliable.
- Reconcile units, signs, percentile definitions, discounting conventions, years, and rounding before editing.
- Keep a list of prose that becomes inaccurate. Change it only when authorized.

### 4. Apply minimal edits

- For short text/numeric substitutions, use `scripts/docx_replace.py` with a reviewed JSON replacement list and expected counts.
- For table cells, update only their `w:t` nodes while retaining paragraph/run/cell properties.
- For Word charts, update both:
  - the corresponding `word/embeddings/*.xlsx` cells; and
  - chart caches in `word/charts/chart*.xml`, including standard and filtered series.
- Preserve chart type, series order, formatting, dimensions, anchors, legends, titles, and colours. Change numeric axis bounds only when stale bounds would misrepresent the new data.
- Leave excluded sections and unrelated package parts byte-identical.

Read [references/workflow.md](references/workflow.md) for chart-cache and package-editing details.

### 5. Verify structure and source integrity

Run:

```powershell
uv run python scripts/docx_diff.py "report v2.docx" "report v3.docx"
uv run python scripts/docx_inventory.py "report v3.docx" --validate
```

- Confirm only intended OOXML parts changed.
- Confirm every source file hash is unchanged.
- Search for stale values, placeholders, formula errors, and unauthorized prose changes.
- Open the new DOCX in Word when available; treat repair prompts as failure.

### 6. Render and inspect every page

Prefer the `documents` skill renderer. On Windows where LibreOffice is unavailable, use:

```powershell
powershell -File scripts/render_docx_word.ps1 -InputDocx "report v3.docx" -OutputPdf "qa/report-v3.pdf"
uv run python scripts/render_pdf.py "qa/report-v3.pdf" --output-dir "qa/pages" --contact-sheet
```

Inspect all page PNGs at full size, plus the contact sheet. Check pagination, clipping, overlaps, fields, tables, charts, fonts, headers, footers, and page numbers.

## Scarlatti style handling

- Existing Scarlatti report: preserve its `styles.xml`, theme, numbering, font table, and nearby formatting; copy a neighboring styled element when adding content.
- Non-Scarlatti report that must be converted: obtain user confirmation before applying `assets/scarlatti-style-parts.zip` with `scripts/apply_scarlatti_style_parts.py`. This replaces style/theme parts but cannot by itself redesign body layout.
- Use orange `#E4813F`, charcoal `#3C3C3C`, teal `#1B998B`, and the other theme colours only through existing theme/style references whenever possible.
- Use Roboto for cover/section display styles and Calibri Light for body text where those styles specify them.

## Delivery

Return only the new DOCX. State that the original document and source files were not modified. Separately list any passages needing prose revision, unresolved placeholders, source ambiguities, or visual limitations.

