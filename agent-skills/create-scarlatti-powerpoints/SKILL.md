---
name: create-scarlatti-powerpoints
description: Create or update editable Scarlatti-branded PowerPoint presentations (.pptx) from the current widescreen template. Use when Codex needs to develop a presentation narrative, plan a deck, create or revise Scarlatti slides, preserve an existing deck's masters and user edits, add native Office charts with embedded workbooks, or visually quality-assure a PowerPoint deliverable.
---

# Create Scarlatti PowerPoints

Create clear, spacious, evidence-led presentations that remain fully editable in Microsoft PowerPoint. Preserve the user's meaning and use the bundled Scarlatti template and native Office objects.

## Read before editing

Read [references/powerpoint-design.md](references/powerpoint-design.md) before planning or editing slides. Use `$scarlatti-designed-outputs` as the broader brand source when it is available; treat the bundled reference as the PowerPoint-specific operating guide.

Read [references/native-chart-spec.md](references/native-chart-spec.md) before adding or replacing a chart.

Use [assets/scarlatti-powerpoint-template-wide-screen-july-2025-v1_1.potx](assets/scarlatti-powerpoint-template-wide-screen-july-2025-v1_1.potx) for a new presentation. Never edit the asset itself. Copy it to a non-SharePoint working location, open the copy in PowerPoint, and save the deliverable as `.pptx`.

Require WSL access to `pwsh.exe` and desktop Microsoft PowerPoint. Require desktop Excel when inserting charts. Do not install packages or create a Python environment for this skill.

## Establish the brief

1. Identify the audience, purpose, delivery setting, desired length, source material, accessibility needs, and client or partner branding.
2. Determine whether the task is a new deck or a targeted update.
3. For an existing deck, inspect and render it before editing. Preserve its masters, layouts, populated placeholders, notes, relationships, and unrelated user changes.
4. Let a supplied client template or explicit client-brand requirement outrank Scarlatti styling. Ask which brand should lead only when the conflict would materially change the output.

## Develop the story

For a new deck or a substantive whole-deck restructure, use this sequence. Skip it for a narrowly targeted edit that does not alter the existing narrative:

1. Draft the narrative if the user has not supplied an outline or narrative.
2. Present that proposed narrative to the user for consideration before creating slides. Do not build the deck until the user has supplied, approved, or revised the narrative. Treat an approved decision-complete Plan-mode plan as approval.
3. Identify the graphics needed to explain the story: charts, diagrams, photographs, tables, maps, timelines, or other visuals. Include only graphics that materially improve comprehension.
4. Divide the narrative into no more than five coherent sections.
5. Write and revise a slide-by-slide content plan. Give each slide one insight, decision, or question; specify its purpose, essential content, and visual treatment.
6. Consider an overview slide showing the sections and estimated speaking time for each. Include it by default when a deck has at least two sections and is not short (normally 10 or more slides or at least 15 minutes). Omit it by default for a one-section or short deck unless requested.

## Build the deck

1. For a new deck, start from a working copy of the bundled `.potx`. Save a new `.pptx` rather than overwriting the template.
2. For an existing deck, start from a working copy of the source `.pptx`; do not rebuild it in the bundled template unless the user explicitly requests a redesign or template migration.
3. In a new deck, reuse the template's masters, named layouts, and representative slides. Delete unused inspiration slides from the working presentation only after preserving the required layouts and examples.
4. Assign each section a distinct template colour family and keep that mapping stable. Use no more than five section colours.
5. When Scarlatti is the lead brand, make `#E4813F` orange visibly present on every slide as a restrained brand thread: an accent rule, section label, bullet, icon, highlighted series, or another meaningful detail.
6. When Scarlatti is the lead brand, use Calibri Light for body copy, tables, charts, labels, and functional text. Retain approved template display typography where the master supplies it.
7. When Scarlatti is the lead brand, use real PowerPoint bullet formatting. Set each bulleted paragraph's bullet to visible and unnumbered, disable `UseTextColor`, and set the bullet font colour to `#E4813F`; keep the paragraph text black or charcoal. Never type `•`, `●`, `-`, or another character to imitate a bullet. Follow the lead client's native bullet treatment in a client-controlled deck.
8. Prefer existing placeholders and layouts over ad-hoc text boxes. Remove genuinely empty slide-level editing placeholders before delivery, but do not remove populated placeholders or modify the master solely to hide placeholders.
9. Use native editable shapes, tables, and charts. Do not flatten a chart to an image or reconstruct a chart from line and text shapes unless the user explicitly requests a static illustration.
10. Keep content concise enough to remain legible at presentation distance. Split slides instead of shrinking body or supporting copy below 14 pt in presentation-only decks; chart labels, axes, notes, and other compact annotations may use the smaller sizes defined in the design reference.

## Insert native charts

Use [scripts/insert-native-chart.ps1](scripts/insert-native-chart.ps1) when a Scarlatti-led deck needs a new or replacement chart. It uses PowerPoint and Excel desktop automation, applies Scarlatti typography and chart styling, and creates a small embedded workbook. For a client-led deck, use it only when the client has accepted that treatment; otherwise create an equivalent native chart that follows the lead client's system.

Run it from WSL by converting every path, including the script path and JSON specification, with `wslpath -w` before passing it to `pwsh.exe`. Use `-NoProfile -ExecutionPolicy Bypass -File`; the process-scoped bypass is required by the tested Windows environment. Supply a new output path unless the user explicitly authorises replacement; use `-Overwrite` only for a known, resolved target. The output directory must already exist.

Chart insertion is not truly headless: PowerPoint requires an active presentation window for `Shapes.AddChart`. The helper launches that required window minimised by default and keeps Excel hidden. Use `-ShowOfficeWindows` only for interactive debugging. The separate slide renderer runs without a presentation window.

The script supports line, clustered or stacked column, clustered or stacked bar, pie, and doughnut charts. It replaces an existing object only by an exact, case-sensitive shape name. Never broaden replacement to a guessed position or bounding box.

Run PowerPoint/Excel automation tasks sequentially. Do not launch chart insertion and rendering concurrently; Office COM is single-instance-sensitive and concurrent calls can make `AddChart` fail nondeterministically.

Close PowerPoint and Excel before running the chart helper. Close PowerPoint before using the renderer; Excel may remain open for rendering. The helpers refuse to run while a relevant Office process is active so they cannot minimise, alter, or quit a user's existing Office session.

## Review and revise

1. Save an intermediate `.pptx` outside SharePoint.
2. Use the headless [scripts/render-slides.ps1](scripts/render-slides.ps1) helper to export every slide to PNG.
3. Inspect every rendered slide at full size and as a deck montage. Revise hierarchy, spacing, alignment, legibility, colour balance, text wrapping, and graphic scale.
4. When Scarlatti is the lead brand, confirm that orange is visible on every slide, bullets are native and orange, and Calibri Light is used for functional text. Otherwise confirm compliance with the lead client's system.
5. Check charts against their source data and inspect native chart relationships and embedded workbooks in the Office package.
6. Reopen the final deck in PowerPoint, verify slide count and chart editability, and run ZIP integrity checks.
7. For a SharePoint deliverable, upload only with explicit permission, then re-fetch or reopen the stored file and verify it matches the tested output.

## Delivery

State the output path, template used, important content or chart changes, and validation performed. Report unresolved source-data, licensing, accessibility, co-branding, or fidelity issues. Do not claim the deck is visually reviewed unless every slide was rendered and inspected.
