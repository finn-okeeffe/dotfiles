---
name: workforce-chart-workflow
description: Create or refresh charts from CCNZ workforce planner model outputs in any working directory using the live Kitty viewer. Use when asked to explore model results, archive previous chart images, make credible-interval lines or posterior histograms, or save charts for automatic display with watch-charts.
---

# Workforce Chart Workflow

Use the user's current working directory as the chart workspace. Do not require it to contain `watch-charts`, `chart_output.py`, `workforce_charts.py`, or an existing `charts/` directory. The `watch-charts` command is expected to be on `PATH`; both it and the archive script create `<working-directory>/charts` when needed.

## Start each chart request

1. Before writing any new image, tell the user: `From this directory, run watch-charts in another Kitty/Zellij pane to see charts as they are saved.` Do not wait for confirmation unless the user asks you to pause.
2. Locate and inspect the requested model output and its dimensions before choosing reductions or selections. Do not assume the model artefacts are at a fixed location when the current directory is elsewhere. Confirm that the needed data can be loaded before moving existing charts.
3. Immediately before saving the first new image, archive the existing image files once:

   ```bash
   bash <skill-directory>/scripts/archive_charts.sh "$PWD/charts"
   ```

   The script moves current PNG, JPEG, GIF, and WebP files into a UTC-timestamped directory under `charts/archive/`. It leaves earlier archives and `.gitkeep` in place. Never archive again after creating charts in the same request.

## Make charts

- Run Python through `uv`; use the project's existing environment and do not install packages without permission.
- When `workforce_charts.py` is available, use it for model discovery, model loading, aggregation, chart styling, credible-interval lines, and posterior histograms. Otherwise use the available model data and reproduce the same chart conventions without copying that module into the working directory.
- Open model outputs returned by the helper with a `with` statement when possible; otherwise call `ModelOutput.close()` after charting so Zarr stores do not remain open.
- When combining artefacts loaded by the helper, call `require_same_run` before comparing them.
- When the helper is available, use `plot_credible_line` or `plot_posterior_histogram` for single-series charts. Call `new_chart` when supplying axes or combining series; these helpers apply the project's Scarlatti styling.
- Before creating regional small multiples, inspect the `region` coordinate. Do not manufacture regional panels from an output whose only region is `New Zealand`; say that a multi-region run is needed.
- For annual average age, calculate an employment-weighted mean from `employed_stock_annual` and the `age_spline` coordinate. The local helper's `annual_average_age(draws)` returns the national all-occupation measure; pass `keep_dims=("occupation",)` or `keep_dims=("region",)` for comparisons.
- For multiple posterior series, use `plot_credible_lines(data, x=..., series=...)`. It draws median lines by default because seven overlapping credible bands usually hide the comparison; set `show_intervals=True` only when the bands remain readable.
- For uncertain time series, prefer `plot_credible_line(..., interval=0.95)` unless the user requests another interval.
- For a posterior distribution at one selected time, occupation, or region, use `plot_posterior_histogram(..., interval=0.95)`.
- Label the measure, units, population, geography, and time period shown. State any aggregation in the title, subtitle, or nearby response.
- Save each finished figure into `<working-directory>/charts` with a descriptive kebab-case PNG filename. Use `chart_output.save_chart` when it is importable; it writes relative to the current working directory. Otherwise create `charts/`, write a hidden temporary PNG there, and replace the final file only after writing finishes. Close the Matplotlib figure after saving.
- Report the saved chart names and any selections or aggregation needed to interpret them.

Keep the work focused on the requested charts. Do not add tests or general documentation unless the user asks.
