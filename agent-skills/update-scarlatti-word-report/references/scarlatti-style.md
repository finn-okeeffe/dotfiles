# Scarlatti Word style reference

This reference is derived from the Scarlatti styles and Office theme embedded in the Hāpi programme-review report. Use style IDs and theme references rather than recreating formatting manually.

## Theme colours

| Role | Hex |
|---|---:|
| Accent 1 — Scarlatti orange | `#E4813F` |
| Accent 2 — charcoal | `#3C3C3C` |
| Accent 3 — teal | `#1B998B` |
| Accent 4 — warm beige | `#CCB99F` |
| Accent 5 — taupe | `#726C60` |
| Accent 6 — dark blue-teal | `#084C61` |
| Light background | `#F8F4EF` |
| White | `#FFFFFF` |
| Black | `#000000` |

Do not introduce unlisted colours unless the source document already uses them or the user requests them.

## Fonts and key styles

- `Normal`: Calibri Light, justified body text.
- `Heading1`: 18 pt bold, page break before, orange bottom rule.
- `Heading2`: 16 pt orange, keep with next.
- `Heading3`: 14 pt black.
- `Heading4`: 12 pt black.
- `Coverpagemaintitle`: Roboto, 28 pt bold.
- `Coverpagesubtitle`: 18 pt bold orange.
- `Sectionpageheading`: Roboto, 32 pt bold.
- `Caption`: bold black, left aligned with deliberate spacing.
- `Inlineemphasis`: bold orange.
- `Tablemainbody`: left aligned with compact 12 pt line spacing.
- `White-Tabletitle`: bold white for teal/dark header fills.
- `Black-Tabletitle`: bold black for light table headers.
- `Tableorfigurenote`: Calibri Light, 9 pt, justified.

Other reusable style IDs include `Coverpageclient`, `Coverpagedate`, `Sectioninformation`, `Sectionpageexplanationtext`, `Overviewparagraph`, `Bulletparagraph`, `Normal-fornumbersbullets`, `Contents`, `TOC1`, `TOC2`, and `TOC3`.

## Tables and charts

- Use teal table headers and pale teal body banding when matching the template.
- Use orange as the primary data series and charcoal/grey for uncertainty or comparison series.
- Use existing chart theme references, number formats, fonts, gridlines, and label positions.
- Preserve figure-caption style and spacing; do not replace charts with screenshots.

The authoritative OOXML style/theme parts are bundled in `assets/scarlatti-style-parts.zip`.

