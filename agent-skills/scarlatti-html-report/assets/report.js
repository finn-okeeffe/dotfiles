/* Scarlatti HTML report behaviour: figure and table numbering, contents list,
   numeric table alignment, SVG charts drawn from data tables, and KaTeX maths.
   Authors never edit this file. */
(function () {
  "use strict";

  const SVGNS = "http://www.w3.org/2000/svg";
  const NAMED = {
    orange: "#E4813F", teal: "#1B998B", charcoal: "#3C3C3C", "deep-blue": "#084C61",
    "blue-teal": "#177E89", sand: "#CCB99F", mustard: "#E7B953", taupe: "#726C60",
    "light-teal": "#C0E0DE", peach: "#F8DDC4", cream: "#F8F4EF", green: "#79A83D", red: "#E4573F",
  };
  const SERIES = ["#E4813F", "#1B998B", "#3C3C3C", "#084C61", "#177E89", "#CCB99F", "#E7B953", "#726C60", "#C0E0DE", "#F8DDC4"];
  const SINGLE = NAMED.teal;
  const FOCUS = NAMED.orange;
  const GRID = "#E3DDD4";
  const BASELINE = "#726C60";
  const TEXT = "#1E1E1E";
  const MUTED = "#5C5850";
  const TYPES = ["column", "bar", "stacked-column", "stacked-bar", "line", "donut"];

  const main = document.querySelector("main.report");
  const chartData = new Map();
  let bodyFont = "Calibri, sans-serif";
  const measureCtx = document.createElement("canvas").getContext("2d");

  /* ---------- helpers ---------- */

  function svgEl(tag, attrs, parent) {
    const node = document.createElementNS(SVGNS, tag);
    for (const [k, v] of Object.entries(attrs || {})) node.setAttribute(k, v);
    if (parent) parent.appendChild(node);
    return node;
  }

  function text(parent, x, y, str, attrs) {
    const t = svgEl("text", Object.assign({ x: x, y: y }, attrs || {}), parent);
    t.textContent = str;
    return t;
  }

  function tip(node, str) {
    svgEl("title", {}, node).textContent = str;
  }

  function textWidth(str, size, weight) {
    measureCtx.font = (weight || 400) + " " + size + "px " + bodyFont;
    return measureCtx.measureText(String(str)).width;
  }

  function wrap(str, maxWidth, size, maxLines) {
    const words = String(str).split(/\s+/).filter(Boolean);
    const lines = [];
    let line = "";
    for (const word of words) {
      const next = line ? line + " " + word : word;
      if (line && textWidth(next, size) > maxWidth) {
        lines.push(line);
        line = word;
      } else {
        line = next;
      }
    }
    if (line) lines.push(line);
    if (maxLines && lines.length > maxLines) {
      const kept = lines.slice(0, maxLines);
      kept[maxLines - 1] = kept[maxLines - 1].replace(/\s*\S*$/, "") + "…";
      return kept;
    }
    return lines.length ? lines : [""];
  }

  function multiline(parent, x, y, lines, size, attrs) {
    const t = svgEl("text", Object.assign({ x: x, y: y, "font-size": size }, attrs || {}), parent);
    lines.forEach((line, i) => {
      const span = svgEl("tspan", { x: x, dy: i === 0 ? 0 : size * 1.2 }, t);
      span.textContent = line;
    });
    return t;
  }

  function parseNum(raw) {
    if (raw == null) return null;
    const s = String(raw).replace(/−/g, "-").replace(/[^0-9.eE+-]/g, "");
    if (s === "" || s === "-" || s === ".") return null;
    const n = parseFloat(s);
    return Number.isFinite(n) ? n : null;
  }

  function luminance(hex) {
    const n = parseInt(hex.slice(1), 16);
    const ch = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => {
      v /= 255;
      return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2];
  }

  function inkOn(hex) {
    const l = luminance(hex);
    return (l + 0.05) / 0.05 >= 1.05 / (l + 0.05) ? TEXT : "#FFFFFF";
  }

  function niceStep(range, count) {
    const raw = range / count;
    const mag = Math.pow(10, Math.floor(Math.log10(raw)));
    const f = raw / mag;
    return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10) * mag;
  }

  function domain(lo, hi, o, count) {
    if (o.min != null) lo = o.min;
    if (o.max != null) hi = o.max;
    if (lo === hi) hi = lo + 1;
    const step = niceStep(hi - lo, count || 5);
    const nlo = o.min != null ? lo : Math.floor(lo / step + 1e-9) * step;
    const nhi = o.max != null ? hi : Math.ceil(hi / step - 1e-9) * step;
    const ticks = [];
    for (let v = Math.ceil(nlo / step - 1e-9) * step; v <= nhi + step / 1e6; v += step) {
      ticks.push(+v.toFixed(10));
    }
    const tickDecimals = (String(+step.toFixed(10)).split(".")[1] || "").length;
    return { lo: nlo, hi: nhi, ticks: ticks, tickDecimals: tickDecimals };
  }

  function rawDomain(lo, hi, o, nice) {
    lo = o.min != null ? o.min : lo;
    hi = o.max != null ? o.max : hi;
    if (lo === hi) hi = lo + 1;
    return { lo: lo, hi: hi, ticks: nice.ticks, tickDecimals: nice.tickDecimals };
  }

  function formatter(o, decimals) {
    return function (v, d) {
      if (v == null) return "";
      const places = d != null ? d : decimals;
      const body = Math.abs(v).toLocaleString("en-NZ", { minimumFractionDigits: places, maximumFractionDigits: places });
      return (v < 0 ? "−" : "") + o.prefix + body + o.suffix;
    };
  }

  function colours(names, o, single) {
    if (o.colors.length) return names.map((_, i) => o.colors[i % o.colors.length]);
    if (o.highlight.length) {
      const rest = single ? [SINGLE] : SERIES.slice(1);
      let k = 0;
      return names.map((nm) => (o.highlight.includes(nm) ? FOCUS : rest[k++ % rest.length]));
    }
    return names.map((_, i) => (single ? SINGLE : SERIES[i % SERIES.length]));
  }

  /* ---------- reading a chart figure ---------- */

  function readOptions(fig) {
    const ds = fig.dataset;
    const list = (s) => (s ? s.split(",").map((x) => x.trim()).filter(Boolean) : []);
    const num = (s) => (s == null || s === "" ? null : parseNum(s));
    return {
      type: (ds.type || "column").trim().toLowerCase(),
      prefix: ds.prefix || "",
      suffix: ds.suffix || "",
      decimals: ds.decimals != null ? parseInt(ds.decimals, 10) : null,
      highlight: list(ds.highlight),
      colors: list(ds.colors).map((c) => NAMED[c.toLowerCase()] || c),
      min: num(ds.min),
      max: num(ds.max),
      height: num(ds.height),
      labels: (ds.labels || "").trim().toLowerCase(),
    };
  }

  function readData(fig) {
    const table = fig.querySelector("table");
    if (!table) throw new Error("This chart has no <table> holding its data.");
    const rows = Array.from(table.rows);
    if (rows.length < 2) throw new Error("The data table needs a header row and at least one data row.");
    const series = Array.from(rows[0].cells).slice(1).map((c) => c.textContent.trim());
    if (!series.length) throw new Error("The header row needs a column heading for each data series.");
    const body = rows.slice(1);
    const categories = body.map((r) => r.cells[0].textContent.trim());
    let decimals = 0;
    const values = series.map((_, s) =>
      body.map((r) => {
        const cell = r.cells[s + 1];
        const raw = cell ? cell.textContent.trim() : "";
        const m = raw.match(/\.(\d+)/);
        if (m) decimals = Math.max(decimals, m[1].length);
        return parseNum(raw);
      })
    );
    if (values.every((sv) => sv.every((v) => v == null))) throw new Error("No numbers were found in the data table.");
    return { table, series, categories, values, decimals: Math.min(decimals, 3) };
  }

  /* ---------- value axis shared by charts ---------- */

  function drawValueGrid(svg, dom, fmtTick, horizontal, box, fs) {
    // horizontal=false: ticks on the left of a vertical value axis
    const g = svgEl("g", {}, svg);
    dom.ticks.forEach((t) => {
      if (horizontal) {
        const x = box.x(t);
        svgEl("line", { x1: x, x2: x, y1: box.top, y2: box.bottom, stroke: GRID, "stroke-width": 1 }, g);
        text(g, x, box.bottom + fs + 4, fmtTick(t), { "font-size": fs - 1, "text-anchor": "middle", fill: MUTED });
      } else {
        const y = box.y(t);
        svgEl("line", { x1: box.left, x2: box.right, y1: y, y2: y, stroke: GRID, "stroke-width": 1 }, g);
        text(g, box.left - 8, y + fs * 0.35, fmtTick(t), { "font-size": fs - 1, "text-anchor": "end", fill: MUTED });
      }
    });
  }

  /* ---------- column charts (grouped or stacked) ---------- */

  function stackExtent(d) {
    let lo = 0, hi = 0;
    d.categories.forEach((_, c) => {
      let pos = 0, neg = 0;
      d.values.forEach((sv) => {
        const v = sv[c] || 0;
        if (v > 0) pos += v; else neg += v;
      });
      hi = Math.max(hi, pos);
      lo = Math.min(lo, neg);
    });
    return [lo, hi];
  }

  function plainExtent(d) {
    let lo = 0, hi = 0;
    d.values.forEach((sv) => sv.forEach((v) => {
      if (v != null) { lo = Math.min(lo, v); hi = Math.max(hi, v); }
    }));
    return [lo, hi];
  }

  function totals(d) {
    return d.categories.map((_, c) => d.values.reduce((sum, sv) => sum + (sv[c] || 0), 0));
  }

  function drawColumns(holder, d, o, stacked) {
    const W = holder.clientWidth || 700;
    const fs = W < 480 ? 12 : 14;
    const nC = d.categories.length, nS = d.series.length;
    const fmt = formatter(o, o.decimals != null ? o.decimals : d.decimals);
    const [elo, ehi] = stacked ? stackExtent(d) : plainExtent(d);
    const nice = domain(elo, ehi, o);
    const fmtTick = (v) => fmt(v, nice.tickDecimals);
    const showLabels = o.labels !== "none";
    const sums = totals(d);
    const showTotals = stacked && nS > 1 && showLabels && new Set(sums.map((s) => s.toFixed(6))).size > 1;
    const seriesCol = colours(d.series, o, false);
    const catCol = colours(d.categories, o, true);
    const colourAt = (s, c) => (nS === 1 ? catCol[c] : seriesCol[s]);
    let dom = nice;

    const H = o.height || 320;
    const groupShare = stacked ? 0.6 : 0.72;
    const tickW = Math.max(...dom.ticks.map((t) => textWidth(fmtTick(t), fs - 1))) + 12;

    function fits(left) {
      const band = (W - left) / nC;
      const barW = stacked ? band * groupShare : (band * groupShare) / nS;
      if (stacked) return true;
      return d.values.every((sv) => sv.every((v) => v == null || textWidth(fmt(v), fs - 1) <= barW + band * (1 - groupShare) / nS - 2));
    }

    let left = 0;
    let axis = o.labels === "axis" || !showLabels || !fits(0);
    if (axis) left = tickW;
    else dom = rawDomain(elo, ehi, o, nice);
    const band = (W - left) / nC;
    const barW = stacked ? band * groupShare : (band * groupShare) / nS;
    const catLines = d.categories.map((c) => wrap(c, band - 6, fs, 3));
    const maxLines = Math.max(...catLines.map((l) => l.length));
    const top = (showLabels && !axis) || showTotals ? fs + 10 : 10;
    const bottom = maxLines * fs * 1.2 + 10;
    const negRoom = !axis && showLabels && !stacked && dom.lo < 0 ? fs + 6 : 0;
    const plotH = H - top - bottom - negRoom;
    const y = (v) => top + ((dom.hi - v) / (dom.hi - dom.lo)) * plotH;

    // stacked segments that cannot hold their label need the axis
    if (stacked && !axis && showLabels) {
      const tooSmall = d.values.some((sv) => sv.some((v) => v && (Math.abs(y(v) - y(0)) < fs + 4 || textWidth(fmt(v), fs - 1) > barW - 4)));
      if (tooSmall) return drawColumns(holder, d, Object.assign({}, o, { labels: "axis" }), stacked);
    }

    const svg = svgEl("svg", { viewBox: `0 0 ${W} ${H}`, class: "chart-svg", role: "img" });
    if (axis) drawValueGrid(svg, dom, fmtTick, false, { left: left, right: W, y: y }, fs);

    d.categories.forEach((cat, c) => {
      const x0 = left + c * band + (band * (1 - groupShare)) / 2;
      let pos = 0, neg = 0;
      d.series.forEach((ser, s) => {
        const v = d.values[s][c];
        if (v == null) return;
        let y1, y2, x, w;
        if (stacked) {
          const base = v >= 0 ? pos : neg;
          y1 = y(base); y2 = y(base + v);
          if (v >= 0) pos += v; else neg += v;
          x = x0; w = barW;
        } else {
          y1 = y(0); y2 = y(v);
          x = x0 + s * barW + (nS > 1 ? 1 : 0); w = barW - (nS > 1 ? 2 : 0);
        }
        const fill = colourAt(s, c);
        const rect = svgEl("rect", { x: x, y: Math.min(y1, y2), width: Math.max(w, 1), height: Math.max(Math.abs(y2 - y1), 0.5), fill: fill }, svg);
        tip(rect, (nS > 1 ? ser + ", " : "") + cat + ": " + fmt(v));
        if (!showLabels) return;
        if (stacked && !axis) {
          text(svg, x + w / 2, (y1 + y2) / 2 + fs * 0.35, fmt(v), { "font-size": fs - 1, "text-anchor": "middle", fill: inkOn(fill) });
        } else if (!stacked && !axis) {
          const ly = v >= 0 ? y2 - 5 : y2 + fs + 2;
          text(svg, x + w / 2, ly, fmt(v), { "font-size": fs - 1, "text-anchor": "middle", fill: TEXT });
        }
      });
      if (showTotals) {
        text(svg, x0 + barW / 2, y(pos) - 5, fmt(sums[c]), { "font-size": fs - 1, "text-anchor": "middle", "font-weight": 700, fill: TEXT });
      }
      multiline(svg, left + c * band + band / 2, H - bottom + fs + 6, catLines[c], fs, { "text-anchor": "middle", fill: TEXT });
    });

    svgEl("line", { x1: left, x2: W, y1: y(0), y2: y(0), stroke: BASELINE, "stroke-width": 1 }, svg);
    return svg;
  }

  /* ---------- horizontal bar charts (grouped or stacked) ---------- */

  function drawBars(holder, d, o, stacked) {
    const W = holder.clientWidth || 700;
    const fs = W < 480 ? 12 : 14;
    const nC = d.categories.length, nS = d.series.length;
    const fmt = formatter(o, o.decimals != null ? o.decimals : d.decimals);
    const [elo, ehi] = stacked ? stackExtent(d) : plainExtent(d);
    const nice = domain(elo, ehi, o);
    const fmtTick = (v) => fmt(v, nice.tickDecimals);
    const showLabels = o.labels !== "none";
    const sums = totals(d);
    const showTotals = stacked && nS > 1 && showLabels && new Set(sums.map((s) => s.toFixed(6))).size > 1;
    const seriesCol = colours(d.series, o, false);
    const catCol = colours(d.categories, o, true);
    const colourAt = (s, c) => (nS === 1 ? catCol[c] : seriesCol[s]);

    const labelW = Math.min(Math.max(...d.categories.map((c) => textWidth(c, fs))), W * 0.35);
    const catLines = d.categories.map((c) => wrap(c, labelW, fs, 3));
    const barH = stacked || nS === 1 ? fs + 10 : fs + 4;
    const rowH = Math.max(stacked || nS === 1 ? barH + 12 : nS * barH + 12, Math.max(...catLines.map((l) => l.length)) * fs * 1.2 + 10);

    const valueLabels = [];
    if (showLabels && !stacked) d.values.forEach((sv) => sv.forEach((v) => v != null && valueLabels.push(textWidth(fmt(v), fs - 1))));
    if (showTotals) sums.forEach((t) => valueLabels.push(textWidth(fmt(t), fs - 1, 700)));
    const endW = valueLabels.length ? Math.max(...valueLabels) + 8 : 6;

    const left = labelW + 12;
    const negPad = elo < 0 && showLabels && !stacked ? endW : 0;
    let axis = o.labels === "axis" || !showLabels;
    let dom = axis ? nice : rawDomain(elo, ehi, o, nice);
    const plotL = left + negPad, plotR = W - endW;
    const x = (v) => plotL + ((v - dom.lo) / (dom.hi - dom.lo)) * (plotR - plotL);

    if (stacked && !axis) {
      const tooSmall = d.values.some((sv) => sv.some((v) => v && Math.abs(x(v) - x(0)) < textWidth(fmt(v), fs - 1) + 8));
      if (tooSmall) { axis = true; dom = nice; }
    }

    const top = 4;
    const H = top + nC * rowH + (axis ? fs + 12 : 4);
    const svg = svgEl("svg", { viewBox: `0 0 ${W} ${H}`, class: "chart-svg", role: "img" });
    if (axis) drawValueGrid(svg, dom, fmtTick, true, { x: x, top: top, bottom: top + nC * rowH }, fs);

    d.categories.forEach((cat, c) => {
      const rowTop = top + c * rowH;
      const groupH = stacked || nS === 1 ? barH : nS * barH;
      const y0 = rowTop + (rowH - groupH) / 2;
      let pos = 0, neg = 0;
      d.series.forEach((ser, s) => {
        const v = d.values[s][c];
        if (v == null) return;
        let x1, x2, yy, h;
        if (stacked) {
          const base = v >= 0 ? pos : neg;
          x1 = x(base); x2 = x(base + v);
          if (v >= 0) pos += v; else neg += v;
          yy = y0; h = barH;
        } else {
          x1 = x(0); x2 = x(v);
          yy = y0 + s * barH + (nS > 1 ? 1 : 0); h = barH - (nS > 1 ? 2 : 0);
        }
        const fill = colourAt(s, c);
        const rect = svgEl("rect", { x: Math.min(x1, x2), y: yy, width: Math.max(Math.abs(x2 - x1), 0.5), height: h, fill: fill }, svg);
        tip(rect, (nS > 1 ? ser + ", " : "") + cat + ": " + fmt(v));
        if (!showLabels) return;
        if (stacked && !axis) {
          text(svg, (x1 + x2) / 2, yy + h / 2 + fs * 0.35, fmt(v), { "font-size": fs - 1, "text-anchor": "middle", fill: inkOn(fill) });
        } else if (!stacked) {
          const lx = v >= 0 ? x2 + 5 : x2 - 5;
          text(svg, lx, yy + h / 2 + fs * 0.35, fmt(v), { "font-size": fs - 1, "text-anchor": v >= 0 ? "start" : "end", fill: TEXT });
        }
      });
      if (showTotals) {
        text(svg, x(pos) + 5, y0 + barH / 2 + fs * 0.35, fmt(sums[c]), { "font-size": fs - 1, "font-weight": 700, fill: TEXT });
      }
      const lines = catLines[c];
      const ly = rowTop + rowH / 2 - ((lines.length - 1) * fs * 1.2) / 2 + fs * 0.35;
      multiline(svg, labelW, ly, lines, fs, { "text-anchor": "end", fill: TEXT });
    });

    svgEl("line", { x1: x(0), x2: x(0), y1: top, y2: top + nC * rowH, stroke: BASELINE, "stroke-width": 1 }, svg);
    return svg;
  }

  /* ---------- line charts ---------- */

  function drawLine(holder, d, o) {
    const W = holder.clientWidth || 700;
    const fs = W < 480 ? 12 : 14;
    const nC = d.categories.length;
    const fmt = formatter(o, o.decimals != null ? o.decimals : d.decimals);
    const all = d.values.flat().filter((v) => v != null);
    const dom = domain(Math.min(0, ...all), Math.max(...all), o);
    const fmtTick = (v) => fmt(v, dom.tickDecimals);
    const cols = colours(d.series, o, false);
    const mode = o.labels || "end";

    const H = o.height || 300;
    const left = Math.max(...dom.ticks.map((t) => textWidth(fmtTick(t), fs - 1))) + 14;
    const ends = d.values.map((sv) => {
      for (let i = sv.length - 1; i >= 0; i--) if (sv[i] != null) return i;
      return -1;
    });
    const endW = mode === "none" ? 0 : Math.max(...d.values.map((sv, s) => (ends[s] >= 0 ? textWidth(fmt(sv[ends[s]]), fs - 1) : 0)));
    const right = W - (endW ? endW + 12 : 8);
    const pad = fs;
    const top = fs + 6, bottom = H - (fs + 14);
    const x = (c) => (nC === 1 ? (left + right) / 2 : left + pad + (c * (right - left - 2 * pad)) / (nC - 1));
    const y = (v) => top + ((dom.hi - v) / (dom.hi - dom.lo)) * (bottom - top);

    const svg = svgEl("svg", { viewBox: `0 0 ${W} ${H}`, class: "chart-svg", role: "img" });
    drawValueGrid(svg, dom, fmtTick, false, { left: left, right: right, y: y }, fs);
    svgEl("line", { x1: left, x2: right, y1: y(dom.lo), y2: y(dom.lo), stroke: BASELINE, "stroke-width": 1 }, svg);

    const spacing = nC > 1 ? (right - left - 2 * pad) / (nC - 1) : W;
    const widest = Math.max(...d.categories.map((c) => textWidth(c, fs)));
    const step = Math.max(1, Math.ceil((widest + 12) / spacing));
    d.categories.forEach((cat, c) => {
      if (c % step !== 0) return;
      text(svg, x(c), H - 4, cat, { "font-size": fs, "text-anchor": "middle", fill: TEXT });
    });

    const endLabels = [];
    d.values.forEach((sv, s) => {
      let dPath = "";
      let pen = false;
      sv.forEach((v, c) => {
        if (v == null) { pen = false; return; }
        dPath += (pen ? "L" : "M") + x(c).toFixed(1) + "," + y(v).toFixed(1);
        pen = true;
      });
      svgEl("path", { d: dPath, fill: "none", stroke: cols[s], "stroke-width": 2.5, "stroke-linejoin": "round", "stroke-linecap": "round" }, svg);
      sv.forEach((v, c) => {
        if (v == null) return;
        if (nC <= 30) {
          const dot = svgEl("circle", { cx: x(c), cy: y(v), r: 3.5, fill: cols[s], stroke: "#FFFFFF", "stroke-width": 1.5 }, svg);
          tip(dot, (d.series.length > 1 ? d.series[s] + ", " : "") + d.categories[c] + ": " + fmt(v));
        }
        if (mode === "all" && c !== ends[s]) {
          text(svg, x(c), y(v) - 9, fmt(v), { "font-size": fs - 2, "text-anchor": "middle", fill: TEXT });
        }
      });
      if (mode !== "none" && ends[s] >= 0) endLabels.push({ y: y(sv[ends[s]]) + fs * 0.35, x: x(ends[s]) + 8, str: fmt(sv[ends[s]]), col: cols[s] });
    });

    // keep end labels from overlapping
    endLabels.sort((a, b) => a.y - b.y);
    for (let i = 1; i < endLabels.length; i++) {
      if (endLabels[i].y - endLabels[i - 1].y < fs + 2) endLabels[i].y = endLabels[i - 1].y + fs + 2;
    }
    endLabels.forEach((l) => text(svg, l.x, l.y, l.str, { "font-size": fs - 1, "font-weight": 700, fill: TEXT }));
    return svg;
  }

  /* ---------- donut charts ---------- */

  function drawDonut(d, o) {
    const fmt = formatter(o, o.decimals != null ? o.decimals : d.decimals);
    const cols = colours(d.categories, o, false);
    const items = d.categories.map((c, i) => ({ name: c, v: d.values[0][i], col: cols[i] })).filter((it) => it.v != null && it.v > 0);
    if (!items.length) throw new Error("A donut chart needs positive values in its first data column.");
    const total = items.reduce((s, it) => s + it.v, 0);
    const S = 240, cx = S / 2, R = S / 2 - 2, r = R * 0.6;

    const wrapDiv = document.createElement("div");
    wrapDiv.className = "chart-donut";
    const svg = svgEl("svg", { viewBox: `0 0 ${S} ${S}`, class: "chart-svg", role: "img" }, wrapDiv);
    let a0 = -Math.PI / 2;
    const pt = (a, rad) => (cx + rad * Math.cos(a)).toFixed(2) + "," + (cx + rad * Math.sin(a)).toFixed(2);
    items.forEach((it) => {
      const frac = it.v / total;
      const a1 = a0 + frac * 2 * Math.PI;
      let path;
      if (frac >= 0.9999) {
        path = `M${pt(-Math.PI / 2, R)}A${R},${R} 0 1 1 ${pt(Math.PI / 2, R)}A${R},${R} 0 1 1 ${pt(-Math.PI / 2, R)}` +
               `M${pt(-Math.PI / 2, r)}A${r},${r} 0 1 0 ${pt(Math.PI / 2, r)}A${r},${r} 0 1 0 ${pt(-Math.PI / 2, r)}Z`;
      } else {
        const large = frac > 0.5 ? 1 : 0;
        path = `M${pt(a0, R)}A${R},${R} 0 ${large} 1 ${pt(a1, R)}L${pt(a1, r)}A${r},${r} 0 ${large} 0 ${pt(a0, r)}Z`;
      }
      const seg = svgEl("path", { d: path, fill: it.col, stroke: "#FFFFFF", "stroke-width": 1.5, "fill-rule": "evenodd" }, svg);
      tip(seg, it.name + ": " + fmt(it.v));
      a0 = a1;
    });

    const ul = document.createElement("ul");
    ul.className = "chart-legend";
    items.forEach((it) => {
      const li = document.createElement("li");
      const pct = ((it.v / total) * 100).toLocaleString("en-NZ", { maximumFractionDigits: 0 });
      li.innerHTML = '<span class="swatch"></span><span></span><b></b>';
      li.firstChild.style.background = it.col;
      li.children[1].textContent = it.name;
      li.children[2].textContent = o.suffix === "%" ? fmt(it.v) : fmt(it.v) + " (" + pct + "%)";
      ul.appendChild(li);
    });
    wrapDiv.appendChild(ul);
    return wrapDiv;
  }

  /* ---------- chart driver ---------- */

  function legend(d, o) {
    const ul = document.createElement("ul");
    ul.className = "chart-legend";
    colours(d.series, o, false).forEach((col, i) => {
      const li = document.createElement("li");
      li.innerHTML = '<span class="swatch"></span><span></span>';
      li.firstChild.style.background = col;
      li.lastChild.textContent = d.series[i];
      ul.appendChild(li);
    });
    return ul;
  }

  function renderChart(fig) {
    let state = chartData.get(fig);
    if (!state) {
      const o = readOptions(fig);
      if (!TYPES.includes(o.type)) throw new Error(`Unknown chart type "${o.type}". Use one of: ${TYPES.join(", ")}.`);
      const d = readData(fig);
      const holder = document.createElement("div");
      holder.className = "chart";
      d.table.parentNode.insertBefore(holder, d.table);
      d.table.classList.add("sr-only");
      state = { o, d, holder, width: 0 };
      chartData.set(fig, state);
    }
    const { o, d, holder } = state;
    const width = holder.clientWidth;
    if (width === state.width) return;
    state.width = width;
    holder.textContent = "";
    if (d.series.length > 1 && o.type !== "donut") holder.appendChild(legend(d, o));
    let out;
    if (o.type === "column") out = drawColumns(holder, d, o, false);
    else if (o.type === "stacked-column") out = drawColumns(holder, d, o, true);
    else if (o.type === "bar") out = drawBars(holder, d, o, false);
    else if (o.type === "stacked-bar") out = drawBars(holder, d, o, true);
    else if (o.type === "line") out = drawLine(holder, d, o);
    else out = drawDonut(d, o);
    const caption = fig.querySelector("figcaption");
    const svg = out.tagName.toLowerCase() === "svg" ? out : out.querySelector("svg");
    svg.setAttribute("aria-label", caption ? caption.textContent.trim() : "Chart");
    holder.appendChild(out);
  }

  function renderCharts() {
    main.querySelectorAll("figure.chart").forEach((fig) => {
      try {
        renderChart(fig);
      } catch (err) {
        if (fig.querySelector(".chart-error")) return;
        const box = document.createElement("div");
        box.className = "chart-error";
        box.textContent = "Chart could not be drawn: " + err.message;
        fig.insertBefore(box, fig.querySelector("table"));
        console.error(err);
      }
    });
  }

  /* ---------- document structure ---------- */

  function numberFigures() {
    let fig = 0, tab = 0;
    main.querySelectorAll("figure").forEach((f) => {
      const cap = f.querySelector(":scope > figcaption");
      if (!cap) return;
      fig += 1;
      cap.insertAdjacentHTML("afterbegin", `<span class="fig-num">Figure ${fig}.</span> `);
    });
    main.querySelectorAll("table > caption").forEach((cap) => {
      if (cap.closest("figure.chart")) return;
      tab += 1;
      cap.insertAdjacentHTML("afterbegin", `<span class="fig-num">Table ${tab}.</span> `);
    });
  }

  function prepareTables() {
    const numeric = /^[−+-]?[$€£]?\s?\d[\d,]*(\.\d+)?\s?(%|k|m|bn)?$/i;
    main.querySelectorAll("table").forEach((table) => {
      if (table.closest("figure.chart")) return;
      if (!table.parentElement.classList.contains("table-wrap")) {
        const wrapDiv = document.createElement("div");
        wrapDiv.className = "table-wrap";
        table.parentNode.insertBefore(wrapDiv, table);
        wrapDiv.appendChild(table);
      }
      const rows = Array.from(table.rows);
      const bodyRows = rows.filter((r) => r.parentElement.tagName !== "THEAD");
      const ncol = Math.max(...rows.map((r) => r.cells.length));
      for (let c = 1; c < ncol; c++) {
        const cells = bodyRows.map((r) => r.cells[c]).filter((cell) => cell && cell.textContent.trim() !== "");
        if (cells.length && cells.every((cell) => numeric.test(cell.textContent.trim()) || /^[–—-]$/.test(cell.textContent.trim()))) {
          rows.forEach((r) => r.cells[c] && r.cells[c].classList.add("num"));
        }
      }
    });
  }

  function buildContents() {
    const heads = Array.from(main.querySelectorAll("h2"));
    if (heads.length < 3) return;
    const nav = document.querySelector("nav.toc");
    const used = new Set();
    const ol = document.createElement("ol");
    heads.forEach((h) => {
      if (!h.id) {
        let base = h.textContent.toLowerCase().trim().replace(/[^\p{L}\p{N}]+/gu, "-").replace(/^-|-$/g, "") || "section";
        let id = base, n = 2;
        while (used.has(id) || document.getElementById(id)) id = base + "-" + n++;
        h.id = id;
      }
      used.add(h.id);
      const li = document.createElement("li");
      const a = document.createElement("a");
      a.href = "#" + h.id;
      a.textContent = h.textContent;
      li.appendChild(a);
      ol.appendChild(li);
    });
    nav.innerHTML = "<p>Contents</p>";
    nav.appendChild(ol);
    nav.hidden = false;
    nav.parentElement.classList.add("has-toc");

    if ("IntersectionObserver" in window) {
      const links = new Map(Array.from(nav.querySelectorAll("a")).map((a) => [a.getAttribute("href").slice(1), a]));
      const observer = new IntersectionObserver((entries) => {
        entries.forEach((e) => {
          if (!e.isIntersecting) return;
          links.forEach((a) => a.classList.remove("active"));
          const a = links.get(e.target.id);
          if (a) a.classList.add("active");
        });
      }, { rootMargin: "0px 0px -70% 0px" });
      heads.forEach((h) => observer.observe(h));
    }
  }

  function renderMaths() {
    if (typeof window.renderMathInElement !== "function") return;
    window.renderMathInElement(main, {
      delimiters: [
        { left: "$$", right: "$$", display: true },
        { left: "\\[", right: "\\]", display: true },
        { left: "\\(", right: "\\)", display: false },
      ],
      ignoredClasses: ["chart", "sr-only", "no-math"],
      throwOnError: false,
    });
  }

  function init() {
    if (!main) return;
    bodyFont = getComputedStyle(document.body).fontFamily || bodyFont;
    numberFigures();
    prepareTables();
    buildContents();
    renderCharts();
    renderMaths();
    let timer;
    window.addEventListener("resize", () => {
      clearTimeout(timer);
      timer = setTimeout(renderCharts, 150);
    });
    // redraw once web fonts arrive so label widths are measured correctly
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(() => {
        chartData.forEach((s) => { s.width = 0; });
        renderCharts();
      });
    }
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
