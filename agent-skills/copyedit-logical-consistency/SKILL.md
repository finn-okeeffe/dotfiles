---
name: copyedit-logical-consistency
description: NZ English logical consistency and claim support checks with mandatory per-issue false-positive filtering. Writes a markdown report to the repository root (default copyedit_logical_consistency_feedback.md).
---

# Copyedit (Logical consistency, NZ English)

Goal: identify logical inconsistencies and claim support problems (without external fact-checking unless explicitly permitted), filter out false positives issue by issue, then write a markdown report to the top level folder.

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

- WORK_DIR: where to write working files. Default: PROJECT_ROOT/.copyedit_logical_consistency
- OUTPUT_MODE: markdown (default) or json
- OUTPUT_PATH:
  - If OUTPUT_MODE=markdown: default PROJECT_ROOT/copyedit_logical_consistency_feedback.md
  - If OUTPUT_MODE=json: required (write filtered issues JSON to this path)
- INCLUDE_CLEAN_VERSION: true or false. Default: false (only set true when the user explicitly asks for a full clean rewrite)

## Outputs

Always do per-issue filtering.

- If OUTPUT_MODE=markdown: write a markdown report to OUTPUT_PATH.
- If OUTPUT_MODE=json: write filtered issues JSON to OUTPUT_PATH.

If INCLUDE_CLEAN_VERSION is true and the user explicitly asked: write PROJECT_ROOT/copyedit_logical_consistency_clean.md.

## What to check (logical consistency pass)

Focus on reasoning and evidence alignment. Do not add issues for claims that are fully supported.

Apply these checks:

- Claim support versus provided evidence (including cited evidence inside the text)
- Internal contradictions
- Scope and quantifier drift
- Modality strength mismatches (may vs will, suggests vs proves)
- Causal claims inferred from correlational evidence
- Selection effects and base-rate neglect
- Wrong denominators
- Unit or period mismatches
- Cherry-picked time windows
- Circular definitions
- Equivocation of key terms

For each issue, set a support_rating field:

- Partially supports
- Does not support
- Contradicts
- No evidence

## Workflow

Throughout, SKILL_DIR means the directory that contains this SKILL.md file.

1. Determine PROJECT_ROOT:

   - If inside a Git repository, set PROJECT_ROOT to the output of:
     git rev-parse --show-toplevel
   - Otherwise, treat the current working directory as PROJECT_ROOT.

2. Determine WORK_DIR:

   - If WORK_DIR was not provided, set it to:
     PROJECT_ROOT/.copyedit_logical_consistency

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
   - critical: internal contradiction or materially unsupported headline claim
   - high: clear evidence mismatch likely to mislead
   - medium: claim strength should be softened, scope clarified, or denominator fixed
   - low: minor precision improvements (avoid nitpicks)

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
     PROJECT_ROOT/copyedit_logical_consistency_feedback.md
   - Run:
     python3 SKILL_DIR/scripts/render_report.py \
       --issues WORK_DIR/issues_filtered.json \
       --out OUTPUT_PATH

9. Clean version (only if the user explicitly requested it):

   - Write to: PROJECT_ROOT/copyedit_logical_consistency_clean.md
   - Preserve author voice and intent.
   - Do not introduce em dashes or en dashes.

10. Confirm completion:

   - Report the output path(s) to the user.
   - Do not paste the entire report in chat unless the user asks.

## Issue schema (JSON)

issues_raw.json must be a JSON array of objects. Required fields:

- uid: optional (merge_issues.py assigns if missing)
- mode: must be "logical_consistency"
- severity: critical, high, medium, low
- location: file name plus section or paragraph if possible
- excerpt: short quote (max 20 words). No newlines.
- problem: 1 to 3 sentences
- suggestion: minimal fix, 1 to 3 sentences
- discretionary: usually false for this mode (true only when it is purely stylistic framing)
- confidence: high, medium, low

Also include:

- support_rating: Partially supports, Does not support, Contradicts, or No evidence
