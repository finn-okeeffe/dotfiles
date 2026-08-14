# Scarlatti PowerPoint design guide

## Contents

- Source and template
- Brand essentials
- Typography and bullets
- Narrative and sections
- Layout and composition
- Charts, tables, and diagrams
- Imagery and accessibility
- Quality gate

## Source and template

Treat the following sources in descending order of precedence:

1. The user's brief, current project material, and client-controlled template or brand rules.
2. The current Scarlatti template and `$scarlatti-designed-outputs` guidance.
3. This PowerPoint-specific reference.

The bundled asset is an unchanged copy of *Scarlatti PowerPoint presentation-only with inspiration and master slides wide-screen July 2025_v1_1 (KG).potx* from the internal SharePoint template library.

- SHA-256: `dfe8d3dcb54b0d62bedc10eb1910744e9c253df5e421c74c334a7b45b42bfe91`
- Format: 16:9 widescreen, 10 x 5.625 inches
- Contents: 29 inspiration slides, one master, and 32 layouts
- Layout families: title; Layout 1–4 colour variants; image layouts; orange-and-grey layouts; final tagline slide
- Available named colour variants include orange, dark grey, yellow, green, blue, light grey, and light teal.

Always work on a copy. Preserve the master and reuse its layouts or representative slides rather than recreating the visual system.

## Brand essentials

Aim for a result that feels clear, warm, analytical, usable, quietly confident, and action-oriented.

Use the active palette:

| Role | Colour | Hex |
| --- | --- | --- |
| Hero accent | Orange | `#E4813F` |
| Primary | Charcoal | `#3C3C3C` |
| Primary | Teal | `#1B998B` |
| Light neutral | Cream | `#F8F4EF` |
| Supporting | Light teal | `#C0E0DE` |
| Supporting | Deep blue | `#084C61` |
| Supporting | Blue teal | `#177E89` |
| Supporting | Sand | `#CCB99F` |
| Supporting | Light peach | `#F8DDC4` |
| Supporting | Mustard | `#E7B953` |
| Muted neutral | Taupe grey | `#726C60` |
| Explicit positive | Green | `#79A83D` |
| Explicit negative | Red-orange | `#E4573F` |

When Scarlatti is the lead brand, make orange visible on every slide, but do not use it as the default background or normal-size body-text colour. Use it as a bullet, rule, section label, icon, highlighted data series, or other controlled accent. Use colour plus labels, symbols, or patterns when colour communicates meaning. Follow the lead client's palette when a client-controlled template takes precedence.

## Typography and bullets

- Use Calibri Light for body copy, tables, chart labels, axes, captions, and functional text.
- Use the template's approved display treatment for section and cover headings. Do not add a third decorative typeface.
- Use sentence case. Write insight-led titles rather than topic labels.
- For presentation-only slides, use body and supporting copy at 16–20 pt where possible and never below 14 pt. Chart labels, axes, notes, and compact annotations may use 11 pt where the visual remains legible. Use 32–36 pt as a typical display-heading range when the layout does not already control it.
- Align body copy left. Keep paragraphs short and use whitespace before reducing font size.

Create bullets through PowerPoint paragraph formatting, not typed characters. For PowerPoint COM automation, apply the equivalent of:

```powershell
$paragraph.ParagraphFormat.Bullet.Visible = -1
$paragraph.ParagraphFormat.Bullet.Type = 1
$paragraph.ParagraphFormat.Bullet.UseTextColor = 0
$paragraph.ParagraphFormat.Bullet.Font.Name = "Calibri Light"
$paragraph.ParagraphFormat.Bullet.Font.Color.RGB = 4162020
```

`4162020` is Office's integer representation of `#E4813F`. Keep the paragraph text black or charcoal. Align every bullet level under its parent and use real indentation rather than spaces.

## Narrative and sections

Build the story around the audience's question, decision, or desired outcome. Use up to five sections and give each a unique, stable template colour family. Choose the colour family to fit the layouts required; do not use special positive or negative colours in a way that implies judgement accidentally.

For at least two sections, normally add an overview slide when the deck is not short (normally 10 or more slides or at least 15 minutes). An overview contains:

- Each section's plain-English name.
- The practical question it answers.
- Its estimated speaking time.
- The same section colour used later in the deck.

Use one central message per slide. A useful slide plan records the slide's purpose, headline, essential evidence, and intended visual.

## Layout and composition

- Use the existing slide layouts, margins, guides, and placeholders.
- Establish hierarchy through position, size, weight, and whitespace before adding boxes or colour.
- Keep most layouts deliberately open; do not fill every corner.
- Align repeated objects precisely and make their dimensions and spacing identical.
- Use rounded-rectangle crops for added photographs when that matches the template treatment.
- Avoid gradients, decorative shadows, excessive cards, stock UI ornaments, crowded collages, and unexplained metaphors.
- Remove empty slide-level placeholders that clutter editing view only after confirming they contain no text, media, chart, table, or required field. Preserve populated placeholders and the master.

## Charts, tables, and diagrams

Choose the simplest visual that answers the question:

- Line for change over time.
- Bar or column for comparison.
- Stacked bar or column for composition.
- Pie or doughnut only for a small, clear parts-of-a-whole comparison.

Use native Office charts with small embedded workbooks. Start chart colours with orange, teal, and charcoal; use orange for the focal series and approved muted colours for context. Keep series meanings and colours stable throughout a deck.

Use Calibri Light labels, direct labels where practical, meaningful units and periods, and appropriate number precision. Remove 3D effects, gradients, heavy gridlines, default borders, redundant legends, and unexplained precision. Do not rely on orange to mean positive or negative.

For tables, use a restrained taupe-grey header where the template supports it, white body cells, Calibri Light text, left-aligned prose, and consistently aligned numbers. Split a table rather than making it illegible.

Use one icon family per deck. Build diagrams from simple native shapes, arrows, and direct labels that show sequence, ownership, evidence, or decisions explicitly.

## Imagery and accessibility

Prefer authentic, licensed images of people thinking, facilitating, researching, making decisions, or doing relevant work in believable settings. Avoid staged corporate clichés, sci-fi AI imagery, generic laptop shots, and tokenistic cultural imagery.

Use charcoal or black normal-size text on white or cream, or white text on a sufficiently dark field. Orange and teal on white are accents rather than normal-size body text. Add meaningful alternative text to informative images and diagrams where supported.

## Quality gate

Confirm all of the following after rendering every slide:

- The main message is understandable within five seconds.
- The narrative and section progression are coherent.
- When Scarlatti leads, every slide contains a visible but restrained orange element.
- When Scarlatti leads, functional text uses Calibri Light and remains readable at presentation distance.
- Every list uses native PowerPoint bullets or numbering; bullet marks are orange when Scarlatti leads.
- Layouts feel spacious, aligned, consistent, and recognisably derived from the template.
- Charts are editable, truthful, labelled, and free of default Office styling.
- Images and icons are relevant, permitted, and consistently treated.
- Colour contrast is appropriate and meaning is not encoded by colour alone.
- The final file opens without repair warnings and contains no stray empty editing placeholders.
