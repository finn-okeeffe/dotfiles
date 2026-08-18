# Word report update workflow

## Contents

1. Versioning and safety
2. Source-data extraction
3. OOXML editing
4. Word chart updates
5. Verification

## 1. Versioning and safety

Create the output copy before edits. Never use Save As on the source from Word or Excel. Keep before/after hashes for all immutable inputs. Use a writable task-local QA directory and delete it after delivery.

## 2. Source-data extraction

Use cached XLSX/XML values only when they are demonstrably current. Prefer native Excel read-only recalculation for macro-enabled models, dynamic arrays, Monte Carlo models, data tables, external links, or inconsistent formula caches. Open with update-links disabled, calculate, read targeted ranges, close with `SaveChanges=False`, and recheck file hashes.

Create a mapping table internally:

| Report location | Old value | New value | Source | Unit/rounding |
|---|---:|---:|---|---|

Resolve low/median/high conventions, date cutoffs, historical lock-in rules, and present-value bases before touching Word.

## 3. OOXML editing

A DOCX is a ZIP package. Preserve all parts not explicitly in scope.

- Use `lxml` with `XMLParser(huge_tree=True)` for large Word XML.
- Replace text across `w:t` or DrawingML `a:t` nodes without moving the whole paragraph into one run.
- Retain `w:rPr`, `w:pPr`, `w:tcPr`, bookmarks, fields, comments, tracked changes, and relationships.
- Update fields only when authorized. TOC and page-number field displays may change when Word renders.
- Do not use `python-docx` to round-trip a complex report if it cannot preserve embedded objects.

## 4. Word chart updates

Inventory `word/charts/chart*.xml`, chart relationships, and `word/embeddings/*.xlsx`.

For each chart:

1. Identify its caption and document-order relationship ID.
2. Identify the embedded workbook from `word/charts/_rels/chartN.xml.rels`.
3. Update typed numeric cells in the embedded workbook while preserving styles, formulas, and number formats.
4. Update `c:numCache` and `c:strCache` for `c:numRef`/`c:strRef` formulas.
5. Include scatter `c:xVal`/`c:yVal` and extension/filtered-series caches whose formulas may appear as `c15:sqref` rather than `c:f`.
6. Keep point indices and `ptCount` consistent; preserve gaps as absent points.
7. Change fixed axis min/max only if old bounds clip or flatten the refreshed data.
8. Render in Word to ensure Word did not repair or ignore the cache.

For charts that have no embedded workbook, update only when the data source is present in the DOCX package and clearly mapped. Never guess.

## 5. Verification

- ZIP integrity: `ZipFile.testzip()` returns `None`.
- Package diff: only intended `document.xml`, chart XML, embedding, or relationship parts changed.
- Content: all target replacements occurred exactly the expected number of times; old values and placeholders are absent where authorized.
- Visual: inspect every rendered page, not just affected pages.
- Source integrity: before/after hashes match for every source workbook and original DOCX.

