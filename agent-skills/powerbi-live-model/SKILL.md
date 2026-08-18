---
name: powerbi-live-model
description: Connect to a running Power BI Desktop tabular model, discover its local Analysis Services endpoint, run DAX/DMV queries, export measure/column metadata, inspect measure dependencies, and map measures or fields to visuals in a PBIX report layout. Use when Codex needs to QA, debug, document, or review an already-open Power BI Desktop report/model, including measure formatting, rendered DAX outputs, relationships between measures, and how fields appear on report pages.
---

# Power BI Live Model

## Overview

Use this skill to work with an open Power BI Desktop report through its local Analysis Services engine and, when available, its PBIX `Report/Layout` metadata. Prefer the bundled PowerShell scripts for repeatable discovery, DAX execution, metadata export, and report visual inspection.

## Workflow

1. Discover the open Desktop instance:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\discover_powerbi_desktop.ps1
   ```
   Use the returned `Port`, `Catalog`, and `PBIXPath`. Reading the port file under Power BI's AppData workspace may require filesystem approval.

2. Run targeted DAX or DMV queries:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_dax.ps1 -Port 60489 -Query 'EVALUATE ROW("Example", [Some Measure])'
   ```
   Omit `-Catalog` to auto-discover the first catalog. Use DAX `EVALUATE` for model values and `$SYSTEM.*` rowsets for metadata.

3. Export model metadata when reviewing many measures:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\export_model_metadata.ps1 -Port 60489 -OutPath .\model_metadata.json
   ```
   Inspect `Measures`, `Columns`, and `Dependencies` for format strings, expressions, hidden flags, and measure references.

4. Inspect report usage from the PBIX file:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\inspect_report_layout.ps1 -PBIXPath "C:\path\report.pbix" -OutPath .\report_layout_usage.json
   ```
   Use this to map fields/measures to pages, visual types, visual names, visual `columnProperties`, and formatting/display-unit overrides. Reading a PBIX outside the workspace may require approval.

## Common Reviews

### Measure Formatting QA

- Export model metadata.
- Group visible measures by `FormatString`.
- Search measure expressions for `FORMAT(...)` literals because text-returning KPI measures bypass model-level numeric formats.
- Run DAX for representative text measures to verify rendered strings.
- Inspect report layout usage to distinguish visible report issues from model-only cleanup.

### Report Appearance Review

- Use `inspect_report_layout.ps1` and filter `FieldUsage` by a measure or field name.
- Check `ColumnProperties` for visual-level `formatString` overrides.
- Check `ObjectProperties` for display-unit and precision settings such as `labelDisplayUnits`, `labelPrecision`, and `detailLabelPrecision`.
- Report page name, visual type, visual name/id, field, and the observed override.

### Dependency Review

- Use `export_model_metadata.ps1` and inspect `Dependencies`.
- Trace from a suspect base measure to dependent KPI/text measures.
- Map dependent measures to report visuals with `inspect_report_layout.ps1`.

## Notes And Constraints

- Power BI Desktop exposes the model through a local `msmdsrv.exe` instance. The port is usually stored in `msmdsrv.port.txt` under `%LOCALAPPDATA%\Microsoft\Power BI Desktop\AnalysisServicesWorkspaces\...\Data`.
- ADOMD.NET is commonly available at `C:\Program Files\Microsoft.NET\ADOMD.NET\160\Microsoft.AnalysisServices.AdomdClient.dll`. If missing, search installed SQL Server/SSMS/Power BI locations for `Microsoft.AnalysisServices.AdomdClient.dll`.
- Prefer `powershell.exe` (Windows PowerShell / .NET Framework) for ADOMD.NET 160 if the current shell is PowerShell 7 and fails with .NET type-loading errors.
- Do not modify PBIX files unless the user explicitly asks. These scripts are read-only.
- If multiple Power BI Desktop instances are open, identify the intended PBIX by command line or ask the user which report to inspect.

## References

- Read `references/report-layout.md` when interpreting PBIX `Report/Layout` visual metadata or mapping fields to visuals.
