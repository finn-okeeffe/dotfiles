---
name: copyedit-repetition-dedup
description: Detect duplicated meaning in NZ English prose and recommend precise keep, cut, or merge actions with paired earlier or later evidence. Use when text repeats claims, definitions, recommendations, caveats, or conclusions across sentences, paragraphs, or sections and needs de-duplication without changing intent.
---

# Copyedit (Repetition de-duplication, NZ English)

Goal: identify repeated ideas, recommend keep, cut, or merge actions, filter false positives one issue at a time, then write a markdown report to the top level folder.

## Hard rules

1. Write in New Zealand English (organisation, programme, travelling).
2. Do not output em dashes or en dashes (Unicode U+2014 and U+2013). Use commas, parentheses, or hyphens instead.
3. Do not flag harmless signposting (for example, heading text echoed in a contents list) or necessary cross references.
4. Do not produce a full clean rewrite of the entire text unless the user explicitly requests it.
5. Do not fact-check with outside sources unless the user explicitly permits it.
6. Preserve author voice and intent. If removal or merge could alter meaning, keep and flag the risk.

## Inputs

Accept any of the following:

- Inline text in the user prompt.
- One or more file paths.
- INPUT_PATH: explicit file path (preferred in multi-skill pipelines).

Optional parameters the user may include:

- WORK_DIR: where to write working files. Default: PROJECT_ROOT/.copyedit_repetition_dedup
- OUTPUT_MODE: markdown (default) or json
- OUTPUT_PATH:
  - If OUTPUT_MODE=markdown: default PROJECT_ROOT/copyedit_repetition_dedup_feedback.md
  - If OUTPUT_MODE=json: required (write filtered issues JSON to this path)
- INCLUDE_CLEAN_VERSION: true or false. Default: false (only set true when the user explicitly asks for a full clean rewrite)

## Outputs

Always do per-issue filtering.

- If OUTPUT_MODE=markdown: write a markdown report to OUTPUT_PATH.
- If OUTPUT_MODE=json: write filtered issues JSON to OUTPUT_PATH.

If INCLUDE_CLEAN_VERSION is true and the user explicitly asked: write PROJECT_ROOT/copyedit_repetition_dedup_clean.md.

## What to check (repetition de-duplication pass)

Treat as duplication when the same proposition is restated without adding material value:

- Exact repeats
- Paraphrases with the same claim
- Repeated definitions
- Repeated recommendations
- Conclusions restated from earlier text
- Background repeated in method or results
- List items repeated across sections
- Caveats repeated with no new nuance

Prioritise what to keep:

- Prefer the earlier, clearer, more specific, or better evidenced instance.
- If one instance includes numbers, citations, limits, or nuance, keep that content.
- Use action values:
  - Keep: keep both instances because each adds unique content.
  - Cut: remove the weaker duplicate.
  - Merge: combine into one sentence that preserves all unique content.

Location guidance:

- Always capture both earlier and later locations.
- If sections are absent, infer paragraph and sentence indices.

Severity guidance:

- high: repeated claim materially harms clarity or argument flow
- medium: meaningful but non-critical repetition
- low: minor repeated phrasing with limited impact

## Workflow

Throughout, SKILL_DIR means the directory that contains this SKILL.md file.

1. Determine PROJECT_ROOT:

   - If inside a Git repository, set PROJECT_ROOT to the output of:
     git rev-parse --show-toplevel
   - Otherwise, treat the current working directory as PROJECT_ROOT.

2. Determine WORK_DIR:

   - If WORK_DIR was not provided, set it to:
     PROJECT_ROOT/.copyedit_repetition_dedup

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

   Use enough CONTEXT from WORK_DIR/input.txt for the filter to judge correctly.

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
     PROJECT_ROOT/copyedit_repetition_dedup_feedback.md
   - Run:
     python3 SKILL_DIR/scripts/render_report.py \
       --issues WORK_DIR/issues_filtered.json \
       --out OUTPUT_PATH

9. Clean version (only if the user explicitly requested it):

   - Write to: PROJECT_ROOT/copyedit_repetition_dedup_clean.md
   - Preserve author voice and intent.
   - Do not introduce em dashes or en dashes.

10. Confirm completion:

   - Report the output path(s) to the user.
   - Do not paste the entire report in chat unless the user asks.

## Issue schema (JSON)

issues_raw.json must be a JSON array of objects. Required fields:

- uid: optional (merge_issues.py assigns if missing)
- mode: must be "repetition_dedup"
- severity: critical, high, medium, low
- location: concise combined location string for the duplication pair
- excerpt: short combined quote (max 20 words). No newlines.
- problem: one to three sentences on why this is duplicated meaning
- suggestion: one to three sentences with the recommended edit
- discretionary: usually false, true only when judgement is borderline
- confidence: high, medium, low

Also include these repetition fields whenever possible:

- earlier_excerpt: short earlier quote (target max 15 words)
- earlier_location: location of earlier quote
- later_excerpt: short later quote (target max 15 words)
- later_location: location of later quote
- dedup_action: Keep, Cut, or Merge
- merged_sentence: required when dedup_action is Merge
