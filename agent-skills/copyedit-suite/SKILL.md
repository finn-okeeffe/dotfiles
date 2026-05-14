---
name: copyedit-suite
description: Multi-pass NZ English copy-edit workflow. Consolidates feedback across general copy editing, repetition de-duplication, advanced style, logical consistency, terminology or units, and formulaic AI-tell patterns. Always filters false positives and nitpicks with one issue per filter pass. Writes a markdown report to copyedit_feedback.md at the repository root.
---

# Copyedit Suite (NZ English)

Goal: run several specialised copy-edit passes, merge the issues into a single standardised set, filter out false positives and nitpicks using per-issue review, then write a single markdown report to the top level folder.

## Hard rules

1. Write in New Zealand English (organisation, programme, travelling).
2. Do not output em dashes or en dashes (Unicode U+2014 and U+2013). Use commas, parentheses, or hyphens instead.
3. Do not produce a full clean rewrite of the entire text unless the user explicitly requests it.
4. Do not flag double spaces as an issue.
5. Do not fact-check with outside sources unless the user explicitly permits it.

## Inputs

Accept any of the following:

- Inline text in the user prompt.
- One or more file paths (for example: report.md, draft.txt). Prefer files when provided.
- If multiple files are given, treat each file as a separate section and preserve file boundaries in locations.

Optional parameters the user may include in their request:

- OUTPUT_PATH: where to write the report. Default: PROJECT_ROOT/copyedit_feedback.md
- RUN_MODES: comma-separated list. Default: general, repetition_dedup, advanced_style, logical_consistency, terminology_units, ai_tells
- INCLUDE_CLEAN_VERSION: true or false. Default: false (only set true when the user explicitly asks for a full clean rewrite)

## Outputs

Always write:

- A markdown report to OUTPUT_PATH (default PROJECT_ROOT/copyedit_feedback.md)

Optionally (only if INCLUDE_CLEAN_VERSION is true and the user explicitly asked):

- A full clean rewrite to PROJECT_ROOT/copyedit_clean.md

## Workflow

Throughout, SKILL_DIR means the directory that contains this SKILL.md file.

1. Determine PROJECT_ROOT:

   - If inside a Git repository, set PROJECT_ROOT to the output of:
     git rev-parse --show-toplevel
   - Otherwise, treat the current working directory as PROJECT_ROOT.

2. Create a working directory at PROJECT_ROOT:

   - PROJECT_ROOT/.copyedit_suite/

3. Capture the input text:

   - If the user provided file paths, read them and concatenate into:
     PROJECT_ROOT/.copyedit_suite/input.txt
     Use clear file boundary markers, for example:
     [FILE: path/to/file.ext]
     ...content...
     [END FILE]

   - If the user provided inline text only, write it to:
     PROJECT_ROOT/.copyedit_suite/input.txt

4. For each requested mode in RUN_MODES, generate candidate issues as JSON.

   Modes and the skills to invoke:
   - general: $copyedit-general
   - repetition_dedup: $copyedit-repetition-dedup
   - advanced_style: $copyedit-advanced-style
   - logical_consistency: $copyedit-logical-consistency
   - terminology_units: $copyedit-terminology-units
   - ai_tells: $copyedit-ai-tells

   For each mode, invoke the relevant skill with:

   - INPUT_PATH=PROJECT_ROOT/.copyedit_suite/input.txt
   - WORK_DIR=PROJECT_ROOT/.copyedit_suite/subskills/<mode>
   - OUTPUT_MODE=json
   - OUTPUT_PATH=PROJECT_ROOT/.copyedit_suite/issues_<mode>.json

   This causes each mode skill to run its own internal false-positive filtering (always on) and then write a filtered issues JSON file to the suite workspace, without generating a markdown report.

   Multi-agent guidance:
   - If multi-agent is enabled, you may run these mode passes in parallel.
   - If multi-agent is not enabled, run them sequentially in the same session.

5. Merge and de-duplicate issues:

   Run:
   - python3 SKILL_DIR/scripts/merge_issues.py \
       --out PROJECT_ROOT/.copyedit_suite/issues_merged.json \
       PROJECT_ROOT/.copyedit_suite/issues_general.json \
       PROJECT_ROOT/.copyedit_suite/issues_repetition_dedup.json \
       PROJECT_ROOT/.copyedit_suite/issues_advanced_style.json \
       PROJECT_ROOT/.copyedit_suite/issues_logical_consistency.json \
       PROJECT_ROOT/.copyedit_suite/issues_terminology_units.json \
       PROJECT_ROOT/.copyedit_suite/issues_ai_tells.json

   If only a subset of modes ran, pass only those files.

6. False-positive and nitpick filtering (always on):

   - Load PROJECT_ROOT/.copyedit_suite/issues_merged.json.
   - For each candidate issue, spawn one sub-agent, and in that sub-agent prompt include $copyedit-fp-filter plus the single issue object and enough of the input text to judge it.
   - Each sub-agent must evaluate exactly one issue (no extra issues) and write a JSON decision to:
     PROJECT_ROOT/.copyedit_suite/decisions/<uid>.json

   Practical limits:
   - If there are many low-severity style issues, you may pre-trim obvious micro-tweaks before spawning sub-agents.
   - Always filter anything that looks like a judgement call (style improvements, punctuation preferences, optional restructures).

   Then run:
   - python3 SKILL_DIR/scripts/apply_fp_decisions.py \
       --issues PROJECT_ROOT/.copyedit_suite/issues_merged.json \
       --decisions_dir PROJECT_ROOT/.copyedit_suite/decisions \
       --out PROJECT_ROOT/.copyedit_suite/issues_filtered.json

7. Render the markdown report:

   - If OUTPUT_PATH was not provided, set it to:
     PROJECT_ROOT/copyedit_feedback.md

   Run:
   - python3 SKILL_DIR/scripts/render_report.py \
       --issues PROJECT_ROOT/.copyedit_suite/issues_filtered.json \
       --out OUTPUT_PATH

   The renderer:
   - Groups issues by status (kept, dismissed)
   - Orders kept issues by severity, then mode, then location
   - Sanitises any forbidden dash characters so the report contains none

8. Confirm completion:

   - Report the output path to the user.
   - Do not paste the entire report in chat unless the user asks.

## Shared issue schema (JSON)

Each issues_<mode>.json file must be a JSON array of objects. Required fields:

- uid: unique id for the issue within the merged set. If you do not set it, merge_issues.py will assign it.
- mode: one of general, repetition_dedup, advanced_style, logical_consistency, terminology_units, ai_tells
- severity: one of critical, high, medium, low
- location: where the issue occurs (file name plus section or paragraph if possible)
- excerpt: a short quote (max 20 words). Do not include newline characters.
- problem: why it is a problem (1 to 3 sentences)
- suggestion: minimal fix (1 to 3 sentences)
- discretionary: true if it is a taste-level style improvement, false if it is an error or ambiguity
- confidence: high, medium, or low

Additional fields are allowed (category, support_rating, notes), but do not remove required fields.
