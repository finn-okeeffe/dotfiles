---
name: scarlatti-html-report
description: Write a one-page Scarlatti-branded HTML report, outline, brief or summary from a fixed template. You write only plain HTML content (headings, paragraphs, lists, tables); the template supplies the layout, logo, typography, contents list, figure numbering, LaTeX maths (KaTeX) and charts drawn from a data table with a chart type. Use when asked for an HTML report, web report, report outline, one-page write-up or shareable HTML summary in Scarlatti style, especially one with equations, charts or images.
---

# Scarlatti HTML report

You write the content. The template handles every formatting decision. Do not write CSS, `<style>`, `<script>`, classes other than those listed below, or inline styles.

## Steps

1. Ask for or infer a descriptive file name, such as `survey-reminder-review`. Put the files where the user wants the report, never in SharePoint. Use the scratchpad if they have not said.
2. Write `<name>.content.html` containing **only the report body**. Do not include `<html>`, `<head>` or `<body>`. Start from [assets/example.content.html](assets/example.content.html) if you want a model.
3. Build it with the script in this skill's `scripts/` folder (shown here at its Claude Code location):

   ```bash
   uv run ~/.claude/skills/scarlatti-html-report/scripts/build.py <name>.content.html
   ```

   This writes `<name>.html`: one self-contained file with the stylesheet, scripts, logo and local images embedded. Fix anything it prints as a `warning:`. Use `-o other.html` to pick a different output name.
4. Optionally check the page by screenshotting it with headless Edge (its minimum window width is about 500 px):

   ```bash
   "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" --headless=new --disable-gpu --hide-scrollbars --window-size=1300,3000 --virtual-time-budget=8000 --screenshot="$(wslpath -w "$PWD")\\check.png" "file:///$(wslpath -w "$PWD/<name>.html")"
   ```

5. Give the user the `.html` path. Edit the `.content.html` file and rebuild for any changes; never edit the built file.

When the content contains maths, the build embeds KaTeX and its fonts, adding about 630 KB. Equations then display offline and in browsers that block external scripts. Only the Roboto heading font comes from the internet, and headings fall back to a system font without it.

## Page structure

Use this order. Only the `<h1>` is required.

```html
<p class="label">Evaluation report</p>          <!-- small orange label: report, outline, brief… -->
<h1>Survey completion fell after the reminder changed</h1>
<p class="lede">One or two sentences giving the main message.</p>
<p class="meta">Prepared for Client · 3 November 2026 · Draft</p>

<section class="summary">                         <!-- cream panel for the key points -->
  <h2>Key findings</h2>
  <ul><li>…</li></ul>
</section>

<h2>Section heading</h2>                          <!-- sections; 3+ <h2> adds a contents list -->
<p>…</p>
<h3>Sub-heading</h3>
<h4>Minor heading</h4>
```

Use one `<h1>`. Use `<h2>` for sections. The Scarlatti logo, footer, contents list and figure and table numbers are added automatically, so do not write them.

## Building blocks

| Need | Write |
| --- | --- |
| Paragraphs, emphasis, links | `<p>`, `<strong>`, `<em>`, `<a href>` |
| Lists | `<ul>` / `<ol>` with `<li>` (orange markers are automatic) |
| Key figures in a row | `<div class="stats"><p><b>53%</b> completion in 2026</p><p><b>1,840</b> invitations</p></div>` |
| Highlighted note | `<aside class="callout"><p>…</p></aside>` |
| Good or bad status note | `<aside class="callout good">` or `<aside class="callout bad">` |
| Two side-by-side columns | `<div class="columns"><div>…</div><div>…</div></div>` (they stack on phones) |
| Quote | `<blockquote><p>…</p><footer>Interviewee, grower</footer></blockquote>` |
| Small print or source | `<p class="note">Source: …</p>` |
| Code | `<code>` inline, `<pre><code>` block |
| Divider | `<hr>` |

### Tables

Write a plain table. Use `<caption>` for a title, which gets a "Table N." number. Header rows go in `<thead>`. Numeric columns are right-aligned automatically, and wide tables scroll on small screens.

```html
<table>
  <caption>Model estimates</caption>
  <thead><tr><th>Term</th><th>Estimate</th></tr></thead>
  <tbody><tr><td>Late reminder</td><td>−0.37</td></tr></tbody>
</table>
```

### Images

```html
<figure>
  <img src="images/site-map.png" alt="Map of the 12 study sites">
  <figcaption>Study sites</figcaption>
</figure>
```

Paths are relative to the content file. The build embeds local images in the page. Always give `alt` text and a `<figcaption>`, which gets a "Figure N." number. Use this for plots made elsewhere, such as matplotlib or R exports.

### Charts

Put the data in a table inside `<figure class="chart">` and choose a type. The first row holds headings: the first cell labels the categories and each other cell names a data series. Each later row is one category. The chart is drawn in Scarlatti colours with direct value labels. The table stays in the page for screen readers.

```html
<figure class="chart" data-type="column" data-suffix="%" data-highlight="2026">
  <figcaption>Completion rate by survey year</figcaption>
  <table>
    <tr><th>Year</th><th>Completion</th></tr>
    <tr><td>2025</td><td>62</td></tr>
    <tr><td>2026</td><td>53</td></tr>
  </table>
  <p class="note">Source: survey platform exports.</p>
</figure>
```

| `data-type` | Use for |
| --- | --- |
| `column` | Comparing a few categories or years. More than one series gives grouped columns. |
| `bar` | Comparing categories with long names, or more than about six categories. |
| `stacked-column`, `stacked-bar` | Composition: parts of each total. |
| `line` | Change over time, with one series per line. |
| `donut` | Parts of one whole, with up to about five parts. Uses only the first data column. |

All other attributes are optional:

| Attribute | Effect |
| --- | --- |
| `data-prefix="$"`, `data-suffix="%"` | Unit text on every value label. Type the bare numbers in the table. |
| `data-decimals="1"` | Fixed decimal places. By default, labels use the most decimals in the data. |
| `data-highlight="2026"` | Colours the named category orange (single series) or the named series orange (several series). Others stay teal or muted. Separate several names with commas. |
| `data-colors="green, sand, red"` | Sets colours in order, per series (or per category for a single series or a donut). Names: `orange`, `teal`, `charcoal`, `deep-blue`, `blue-teal`, `sand`, `mustard`, `taupe`, `light-teal`, `peach`, `green`, `red`, or a hex code. Keep `green` and `red` for good and bad status. |
| `data-min`, `data-max` | Fixes the value range. Bar and column charts start at zero by default. |
| `data-height="360"` | Height in pixels for column and line charts (default 320 and 300). |
| `data-labels="none"`, `"axis"` or `"all"` | `none` hides value labels and shows an axis. `axis` shows an axis instead of labels. `all` labels every point on a line chart, which by default labels only line ends. |

Leave a cell empty for a missing value. A line chart breaks the line there. If a chart cannot be drawn, the page shows a red message saying why, and the data table stays visible.

### Maths

Write LaTeX between `\( … \)` for inline maths, and between `\[ … \]` or `$$ … $$` for display equations. A single `$` is **not** a delimiter, so dollar amounts are safe. Inside HTML, write `<` as `&lt;` and `&` as `&amp;`, or use `\lt` and `\gt`. Add `class="no-math"` to an element whose text should not be treated as maths.

```html
<p>The effect is \(\beta_1\) in</p>
$$\operatorname{logit}\Pr(y_i = 1) = \beta_0 + \beta_1 x_i$$
```

## Writing

The template applies the Scarlatti visual rules, so you do not need to read the full `scarlatti-designed-outputs` guidelines. Do follow its writing rules:

- Write in New Zealand English, with sentence-case headings.
- Make the `<h1>`, the lede and chart captions state the finding, for example "Completion fell after the reminder moved", rather than a topic such as "Survey results".
- Put the answer first: lede, then key findings, then the evidence.
- Keep paragraphs short. Move dense detail into a table, chart or `<h2>Appendix</h2>`.
- Be accurate about uncertainty and limitations. A `callout` suits a caveat.
- End with a clear next step or decision where one exists.
- For an outline, set `<p class="label">Project outline</p>` and use `<h2>` sections with bullet lists. Charts and maths are optional.

## Files

- `assets/template.html`: the page shell (header, contents list, footer). It is filled in by the build.
- `assets/report.css`: all styling, including print to A4.
- `assets/report.js`: numbering, contents list, table alignment, charts and maths.
- `assets/scarlatti-primary-tagline-right.png`: an unmodified copy of the logo from `scarlatti-designed-outputs`.
- `assets/example.content.html`: a full example that uses every building block.
- `assets/katex/`: KaTeX 0.16.11 (MIT licence) from the npm package: `katex.min.js`, `auto-render.min.js`, `katex.min.css` and the WOFF2 fonts.
- `scripts/build.py`: builds the self-contained page. It uses only the Python standard library.
