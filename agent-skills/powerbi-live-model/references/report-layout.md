# PBIX Report Layout Notes

Power BI Desktop PBIX files are zip containers. Classic PBIX reports usually contain `Report/Layout`, a UTF-16 JSON document with page and visual metadata.

## Useful Paths

- `sections[]`: report pages.
- `sections[].displayName`: page name shown to users.
- `sections[].visualContainers[]`: visuals on a page.
- `visualContainers[].config`: JSON string containing visual metadata.
- `config.singleVisual.visualType`: visual type, such as `lineChart`, `card`, or a custom visual id.
- `config.singleVisual.projections`: query references assigned to visual wells.
- `config.singleVisual.columnProperties`: field display names and visual-level `formatString` overrides.
- `config.singleVisual.objects`: visual formatting panes, including label, axis, display-unit, and precision settings.
- `visualContainers[].query`: semantic query JSON string.
- `visualContainers[].dataTransforms`: data transform JSON string.

## Review Pattern

1. Parse `Report/Layout` as UTF-16 JSON.
2. For each visual, parse `config` as JSON.
3. Search across `config`, `query`, and `dataTransforms` for measure/field names.
4. Capture page name, visual type, visual id/name, query references, `columnProperties`, and formatting object properties.
5. Treat custom visuals carefully: many store important user-visible text in custom object properties rather than standard chart wells.

## Formatting Properties Worth Checking

- `formatString`: visual-level field format override.
- `labelDisplayUnits`: display units, often `1D` for none.
- `labelPrecision`: label decimal places.
- `detailLabelPrecision`: detail label decimal places.
- Axis and label objects can have separate overrides.

Report layout inspection is static. Pair it with live DAX queries when you need to verify actual rendered text from measures that use `FORMAT(...)`.
