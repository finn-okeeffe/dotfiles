---
name: copyedit-advanced-style
description: Advanced NZ English style refinement (clarity, flow, readability) with mandatory per-issue false-positive filtering. Writes a markdown report to the repository root (default copyedit_advanced_style_feedback.md).
---

# Copyedit (Advanced style, NZ English)

Goal: propose higher-level style improvements (clarity, flow, readability) even when grammar is technically correct, filter out nitpicks and false positives issue by issue, then write a markdown report to the top level folder.

## Hard rules

1. Write in New Zealand English (organisation, programme, travelling).
2. Do not output em dashes or en dashes (Unicode U+2014 and U+2013). Use commas, parentheses, or hyphens instead.
3. Do not flag double spaces as an issue.
4. Do not produce a full clean rewrite of the entire text unless the user explicitly requests it.
5. Do not fact-check with outside sources unless the user explicitly permits it.
6. Preserve the author’s voice and intent. If a change might alter meaning, flag it rather than applying it.

## Inputs

Accept any of the following:

- Inline text in the user prompt.
- One or more file paths.
- INPUT_PATH: explicit file path (preferred in multi-skill pipelines).

Optional parameters the user may include:

- WORK_DIR: where to write working files. Default: PROJECT_ROOT/.copyedit_advanced_style
- OUTPUT_MODE: markdown (default) or json
- OUTPUT_PATH:
  - If OUTPUT_MODE=markdown: default PROJECT_ROOT/copyedit_advanced_style_feedback.md
  - If OUTPUT_MODE=json: required (write filtered issues JSON to this path)
- INCLUDE_CLEAN_VERSION: true or false. Default: false (only set true when the user explicitly asks for a full clean rewrite)

## Outputs

Always do per-issue filtering.

- If OUTPUT_MODE=markdown: write a markdown report to OUTPUT_PATH.
- If OUTPUT_MODE=json: write filtered issues JSON to OUTPUT_PATH.

If INCLUDE_CLEAN_VERSION is true and the user explicitly asked: write PROJECT_ROOT/copyedit_advanced_style_clean.md.

## What to check (advanced style pass)

Sentence-level edits are expected. You may also propose paragraph restructuring for flow and coherence where justified, preserving the argument and factual content.

Apply these checks:

- Active voice when it improves clarity and does not require inventing an agent
- Concision and removal of weak openers (example: "There is/are", "It is important to note")
- De-nominalise where it clarifies meaning, keeping necessary hedging (may, suggests, likely)
- Split over-long sentences, combine choppy sequences where flow improves
- Consistent register and tone (avoid colloquialisms and intensifiers)
- NZ English spelling conventions
- Follow the source’s percent or per cent convention
- Follow the source’s Oxford comma convention unless it creates ambiguity (flag possible ambiguity)

Discretionary edits:

- Mark discretionary changes with discretionary=true and keep severity low unless clarity impact is material.

## Workflow

Throughout, SKILL_DIR means the directory that contains this SKILL.md file.

1. Determine PROJECT_ROOT:

   - If inside a Git repository, set PROJECT_ROOT to the output of:
     git rev-parse --show-toplevel
   - Otherwise, treat the current working directory as PROJECT_ROOT.

2. Determine WORK_DIR:

   - If WORK_DIR was not provided, set it to:
     PROJECT_ROOT/.copyedit_advanced_style

   Create:
   - WORK_DIR/
   - WORK_DIR/decisions/

3. Capture the input text into:

   - WORK_DIR/input.txt

   If multiple files are provided, include file boundary markers:
   [FILE: path/to/file.ext]
   ...content...
   [END FILE]

4. Generate candidate issues as JSON (unfiltered):

   - Read WORK_DIR/input.txt
   - Produce a JSON array of issue objects using the issue schema below
   - Write JSON only to:
     WORK_DIR/issues_raw.json

   Severity guidance for this mode:
   - high: major clarity, coherence, or readability failures
   - medium: noticeable improvement to clarity or flow
   - low: minor readability improvements (avoid micro-tweaks)

5. Assign uids and normalise fields:

   Run:
   - python3 SKILL_DIR/scripts/merge_issues.py \
       --out WORK_DIR/issues_merged.json \
       WORK_DIR/issues_raw.json

6. False-positive and nitpick filtering (always on):

   - Load WORK_DIR/issues_merged.json.
   - For each issue, run $copyedit-fp-filter on exactly that one issue (no extra issues).
   - Write one decision JSON file per issue to:
     WORK_DIR/decisions/<uid>.json

7. Apply decisions:

   Run:
   - python3 SKILL_DIR/scripts/apply_fp_decisions.py \
       --issues WORK_DIR/issues_merged.json \
       --decisions_dir WORK_DIR/decisions \
       --out WORK_DIR/issues_filtered.json

8. Write outputs:

   If OUTPUT_MODE=json:
   - Write WORK_DIR/issues_filtered.json to OUTPUT_PATH.

   If OUTPUT_MODE=markdown:
   - If OUTPUT_PATH was not provided, set it to:
     PROJECT_ROOT/copyedit_advanced_style_feedback.md
   - Run:
     python3 SKILL_DIR/scripts/render_report.py \
       --issues WORK_DIR/issues_filtered.json \
       --out OUTPUT_PATH

9. Clean version (only if the user explicitly requested it):

   - Write to: PROJECT_ROOT/copyedit_advanced_style_clean.md
   - Preserve author voice and intent.
   - Do not introduce em dashes or en dashes.

10. Confirm completion:

   - Report the output path(s) to the user.
   - Do not paste the entire report in chat unless the user asks.

## Issue schema (JSON)

issues_raw.json must be a JSON array of objects. Required fields:

- uid: optional (merge_issues.py assigns if missing)
- mode: must be "advanced_style"
- severity: critical, high, medium, low
- location: file name plus section or paragraph if possible
- excerpt: short quote (max 20 words). No newlines.
- problem: 1 to 3 sentences
- suggestion: minimal fix, 1 to 3 sentences
- discretionary: true for taste-level changes, otherwise false (for this mode, many will be true)
- confidence: high, medium, low

Do not include fully acceptable passages.
