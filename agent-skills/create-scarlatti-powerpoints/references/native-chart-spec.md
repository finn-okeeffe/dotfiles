# Native chart specification

## Contents

- Invocation
- JSON structure
- Supported chart types
- Defaults and styling
- Replacement and safety
- Examples

## Invocation

This helper applies Scarlatti typography and chart styling. Use it for Scarlatti-led decks, or only with explicit acceptance of that treatment in a client-led deck.

Run the helper from WSL with Windows-resolved paths. Set `skill_dir` to this skill's absolute directory and use absolute paths for the working files:

```bash
skill_dir="/absolute/path/to/create-scarlatti-powerpoints"
deck="/absolute/path/to/working-deck.pptx"
output="/absolute/path/to/working-deck-with-chart.pptx"
spec="/absolute/path/to/chart.json"
pwsh.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w "$skill_dir/scripts/insert-native-chart.ps1")" \
  -SourcePath "$(wslpath -w "$deck")" \
  -OutputPath "$(wslpath -w "$output")" \
  -SlideNumber 6 \
  -SpecPath "$(wslpath -w "$spec")"
```

Use `-ReplaceShapeName "Existing chart name"` only when the exact shape has been inspected. Use `-Overwrite` only when replacing a resolved output file is intentional.

The source deck and specification must already exist, and the parent of each requested output path must exist. The chart helper creates the output `.pptx`; the renderer creates its final output directory when that directory is absent.

Close PowerPoint and Excel before using the chart helper, and close PowerPoint before using the renderer. Both helpers refuse to run when a relevant Office process is active so they own the automation instance they minimise or quit. Chart insertion is not truly headless: PowerPoint's `Shapes.AddChart` requires an active presentation window and fails in no-window mode, while PowerPoint rejects setting `Application.Visible` to false. The helper therefore starts PowerPoint with the required window minimised by default and keeps Excel hidden. Use `-ShowOfficeWindows` only when interactive debugging is useful. The separate slide renderer runs headlessly, with no presentation window.

Run Office automation sequentially. Do not run chart insertion, slide rendering, or another PowerPoint COM task in parallel; PowerPoint can reuse one automation instance and cause intermittent `AddChart` failures.

Render a deck headlessly with:

```bash
skill_dir="/absolute/path/to/create-scarlatti-powerpoints"
deck="/absolute/path/to/working-deck.pptx"
renders="/absolute/path/to/rendered-slides"
pwsh.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w "$skill_dir/scripts/render-slides.ps1")" \
  -PresentationPath "$(wslpath -w "$deck")" \
  -OutputDirectory "$(wslpath -w "$renders")"
```

The renderer uses a width of 1600 pixels by default and derives height from the deck's native aspect ratio when `-Height` is omitted. `-Width` accepts 320–7680 pixels; an explicit `-Height` accepts 180–4320 pixels and must match the deck's aspect ratio within 1%. It renders into a temporary sibling directory and publishes the complete set only after every slide succeeds. `-Overwrite` replaces the complete prior `slide-NNN.png` set; use a fresh directory if it contains unrelated files.

## JSON structure

Required fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `chartType` | string | One supported chart type below |
| `bounds` | object | `left`, `top`, `width`, and `height` in points |
| `categories` | array | Category labels in display order |
| `series` | array | One or more named numeric series |

Bounds use slide points: `left` and `top` must be non-negative, `width` and `height` must be positive, and the resulting rectangle must fit within the slide.

Optional chart fields:

| Field | Default | Meaning |
| --- | --- | --- |
| `name` | `Scarlatti native chart` | PowerPoint shape name |
| `title` | none | Chart-native title |
| `showLegend` | `false` | Show a chart-native legend |
| `legendPosition` | `bottom` | `bottom`, `top`, `left`, or `right` |
| `legendSize` | `11` | Legend font size in points |
| `showGridlines` | `false` | Show value-axis major gridlines |
| `titleSize` | `14` | Chart-title font size in points |
| `categoryAxis` | defaults | Axis title, labels, interval, and number format |
| `valueAxis` | defaults | Axis title, labels, minimum, maximum, major unit, and number format |
| `holeSize` | `55` | Doughnut-hole percentage from 10 to 90 |

Axis and gridline fields apply only to line, bar, and column charts; supplying them for pie or doughnut charts is rejected. `holeSize` applies only to doughnut charts.

Each series requires `name` and `values`. Optional series fields are:

| Field | Default | Meaning |
| --- | --- | --- |
| `role` | palette order | `focal`, `context`, `positive`, or `negative`; line/bar/column only |
| `colour` | role/palette | Explicit `#RRGGBB` override; line/bar/column only |
| `pointColours` | palette order | Pie/doughnut point colours as one `#RRGGBB` value per category |
| `weight` | `2.25` | Line-chart line weight in points |
| `dashStyle` | `solid` | Line charts only: `solid`, `dash`, `dot`, or `long-dash` |
| `markerStyle` | `none` | Line charts only: `none`, `circle`, `square`, `diamond`, or `triangle` |
| `dataLabels` | `none` | `none`, `all`, or `last` |
| `labelPosition` | native chart default | Position subject to the compatibility table below |
| `labelSize` | `11` | Data-label font size in points |
| `labelText` | value | Custom text for a `last` label |
| `showCategoryName` | `false` | Include the category in applied labels |
| `showSeriesName` | `false` | Include the series name in applied labels |
| `showPercentage` | `false` | Include percentage; pie/doughnut only |
| `showValue` | `true`, or `false` when percentage is shown | Include the numeric value |
| `numberFormat` | axis/default | Number format for labels |

Use JSON `null` only for a missing item inside a series' `values` array. All non-null series values must be numeric, and each series must have exactly as many values as there are categories. `dataLabels: "all"` skips missing values; `dataLabels: "last"` labels the last non-null value and adds no label when the series is entirely missing. Optional string, number, and boolean fields are type-checked; omit an unused optional field instead of setting it to `null`. Pie and doughnut charts accept exactly one series, require non-negative values with a positive total, and treat missing values as absent parts. When supplied, `pointColours` must also contain exactly one valid hex colour per category.

Both `categoryAxis` and `valueAxis` accept `title`, `titleSize` (default `11`), `showLabels`, `labelSize` (default `11`), and `numberFormat`. `categoryAxis` also accepts `labelInterval`; `valueAxis` accepts `minimum`, `maximum`, and `majorUnit`.

Label-position compatibility:

| Chart type | Supported explicit positions |
| --- | --- |
| Line | `best-fit`, `above`, `below`, `left`, `right`, `centre` |
| Bar/column | `centre`, `inside-end`, `outside-end` |
| Pie | `best-fit`, `centre`, `inside-end`, `outside-end` |
| Doughnut | `centre`, `inside-end`, `outside-end`; `best-fit` is accepted but left to PowerPoint's native automatic placement because some builds reject the explicit constant |

## Supported chart types

- `line`
- `clustered-column`
- `stacked-column`
- `clustered-bar`
- `stacked-bar`
- `pie`
- `doughnut`

## Defaults and styling

The helper creates a native Office chart and writes its data to an embedded worksheet named `Chart data`. It deliberately deletes the sample series and creates explicit worksheet formulas instead of relying on `SetSourceData`, which is unreliable through PowerPoint automation.

The default series order is orange, teal, charcoal, blue teal, sand, mustard, light teal, and deep blue. Use `role: "focal"` to force Scarlatti orange on line, bar, and column charts. Use positive and negative roles only when the data actually encodes those meanings. Pie and doughnut charts colour points in palette order unless `pointColours` is supplied.

Chart and plot-area fills and borders are removed. Chart titles, legends, axes, and labels use Calibri Light. Gridlines are off by default. Data-label number formats inherit the value-axis format unless the series overrides it. Line and outside labels use charcoal on transparent backgrounds; labels inside filled bars or columns use contrasting text. Circular labels use a restrained white backing for contrast. Add direct labels or a legend whenever the chart would otherwise be ambiguous.

## Replacement and safety

The helper never deletes shapes by geometry or approximate text. `-ReplaceShapeName` must match exactly one object on the target slide, including case. If there are zero or multiple exact matches, the script fails without saving an output. A replacement chart is restored to the target shape's layer position. The chart specification's `name` must not collide with another shape name unless that object is the exact replacement target.

The script saves to a temporary `.pptx`, closes PowerPoint, and then moves the completed file to the output path. It refuses an existing output or a same-path save unless `-Overwrite` is supplied, and rechecks the destination before publication so a file changed or created during automation is not overwritten.

## Examples

Line chart with a direct end label:

```json
{
  "name": "Workforce shortage paths chart",
  "chartType": "line",
  "bounds": {"left": 54, "top": 157, "width": 355, "height": 160},
  "categories": ["2026", "2031", "2036", "2041", "2046"],
  "series": [
    {
      "name": "Central estimate",
      "values": [2, 6, 10, 13.5, 17],
      "role": "focal",
      "weight": 3,
      "dataLabels": "last",
      "labelText": "Central estimate"
    },
    {
      "name": "Plausible high",
      "values": [5, 10, 15, 20, 24],
      "role": "context",
      "dashStyle": "dash"
    }
  ],
  "valueAxis": {"minimum": 0, "maximum": 25, "majorUnit": 5, "showLabels": false},
  "showGridlines": false
}
```

Clustered column chart:

```json
{
  "chartType": "clustered-column",
  "bounds": {"left": 72, "top": 145, "width": 600, "height": 280},
  "categories": ["North", "Central", "South"],
  "series": [
    {"name": "2025", "values": [42, 35, 31], "role": "context"},
    {"name": "2026", "values": [48, 39, 37], "role": "focal", "dataLabels": "all"}
  ],
  "showLegend": true,
  "legendPosition": "bottom",
  "valueAxis": {"minimum": 0, "numberFormat": "0"}
}
```

Doughnut chart:

```json
{
  "chartType": "doughnut",
  "bounds": {"left": 110, "top": 140, "width": 400, "height": 300},
  "categories": ["Complete", "In progress", "Not started"],
  "series": [
    {
      "name": "Projects",
      "values": [18, 7, 3],
      "dataLabels": "all",
      "showCategoryName": true,
      "showPercentage": true,
      "labelPosition": "best-fit"
    }
  ],
  "showLegend": false,
  "holeSize": 58
}
```
