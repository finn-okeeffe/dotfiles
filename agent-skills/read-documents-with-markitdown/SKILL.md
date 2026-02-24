---
name: read-documents-with-markitdown
description: Read/convert .pdf, .pptx, .docx, .xlsx, and .xlsm (values only) to Markdown using the `markitdown` CLI via stdout or `>` redirection (do NOT use `-o`).
compatibility: Requires `markitdown` on PATH (and optional format deps like `markitdown[pdf,docx,pptx,xlsx]`).
disable-model-invocation: false
---

# read-documents-with-markitdown

## Overview

Use `markitdown` to extract content from:
- PDF (`.pdf`)
- PowerPoint (`.pptx`)
- Word (`.docx`)
- Excel (`.xlsx`, `.xlsm`) **DATA/VALUES ONLY** (not formulas; macros ignored)

## When to Use

Use this skill when you need to:
- Read or quote from one of the supported file types
- Summarize/analyze a document provided in one of these formats
- Convert one of these formats into Markdown so you can then read it normally

## Instructions

### 1) Prefer stdout (fast path)

Run `markitdown` and read from stdout:

- `markitdown "<source-file>"`

If the path contains spaces, you MUST quote it.

### 2) If you need a saved artifact, redirect stdout to a `.md` file (REQUIRED; `-o` is broken)

When the output needs to be persisted (large docs, repeated use, downstream parsing), write a markdown file using shell redirection:

- `markitdown "<source-file>" > "<document-name>.md"`

Then read `"<document-name>.md"` with the normal file reader tools.

Rules:
- You MUST NOT use `markitdown -o ...` (broken in this environment).
- Write outputs into the **current directory** unless the user asked for a specific location.

### 3) Excel note: values/data only (NOT formulas)

For `.xlsx` / `.xlsm`, treat `markitdown` output as **VALUES/DATA ONLY** (what you see in cells). You SHOULD NOT assume it extracts formulas, named ranges, or workbook logic. (`.xlsm` macros/VBA are not part of the extracted data.)

If you need formulas or workbook structure, use other tools (example: Python `openpyxl`):
- **Formulas**: load with `data_only=False`
- **Computed values**: load with `data_only=True`

Minimal `openpyxl` pattern:
- `python -c 'import openpyxl as x; wb=x.load_workbook(\"file.xlsm\", data_only=False); ws=wb.active; print(ws[\"A1\"].value)'`

### 4) If conversion fails

If `markitdown` errors due to missing optional dependencies, keep the error message and suggest installing the needed extras (depending on file type), e.g.:
- `pip install 'markitdown[pdf]'`
- `pip install 'markitdown[docx]'`
- `pip install 'markitdown[pptx]'`
- `pip install 'markitdown[xlsx]'`
Or all at once:
- `pip install 'markitdown[all]'`

