---
name: copyedit-ai-tells
description: Flag formulaic AI-tell patterns in writing, with evidence and minimal revision advice. Use when Codex is asked to review prose for AI-sounding tells, generic LLM style, over-polished but empty writing, template-generated headings, or the specific AI-tell categories in this skill. Writes a markdown report by default to copyedit_ai_tells_feedback.md.
---

# Copyedit AI Tells

Goal: flag only the defined AI-tell patterns, explain why each instance weakens the prose, and suggest a concrete human edit. Treat every finding as a style risk, not proof that text was written by AI.

## Hard Rules

1. Limit findings to the categories in "Tell Categories". Do not add other style, grammar, factual, or copy-edit issues.
2. Do not claim that a passage was AI-generated. Say it "reads as AI-like", "sounds formulaic", or "creates an AI-tell risk".
3. Do not flag an isolated word or construction when it is precise, idiomatic, or necessary in context.
4. Prefer fewer, higher-confidence findings over long lists of weak signals.
5. Write in New Zealand English.
6. Do not output em dashes or en dashes. Use commas, parentheses, or hyphens.
7. Do not fact-check with outside sources unless the user explicitly permits it.
8. Do not produce a full clean rewrite unless the user explicitly asks.

## Inputs

Accept any of the following:

- Inline text in the user prompt.
- One or more file paths.
- INPUT_PATH: explicit file path, preferred in multi-skill pipelines.

Optional parameters:

- WORK_DIR: where to write working files. Default: PROJECT_ROOT/.copyedit_ai_tells
- OUTPUT_MODE: markdown (default) or json
- OUTPUT_PATH:
  - If OUTPUT_MODE=markdown: default PROJECT_ROOT/copyedit_ai_tells_feedback.md
  - If OUTPUT_MODE=json: required
- INCLUDE_CLEAN_VERSION: true or false. Default: false. Only set true when the user explicitly asks for a clean rewrite.

## Outputs

Always write either:

- A markdown report to OUTPUT_PATH.
- Filtered issue JSON to OUTPUT_PATH when OUTPUT_MODE=json.

If INCLUDE_CLEAN_VERSION is true and the user explicitly asked, also write PROJECT_ROOT/copyedit_ai_tells_clean.md.

## Tell Categories

Flag only these types of tells:

- Formulaic openings: "In today's world", "In an increasingly", "When it comes to".
- Overly balanced structure: every issue gets neat pros, cons, and a middle-ground conclusion.
- Generic signposting that is unnecessary in context: "Moreover", "Furthermore", "Additionally", "It is important to note".
- Abstract nouns over concrete detail: "landscape", "ecosystem", "framework", "journey", "realm".
- Inflated verbs: "leverage", "utilise", "enhance", "foster", "empower", "streamline".
- Soft, noncommittal claims: "can help", "may provide", "often plays a role", "is important".
- Generic conclusions: "In conclusion", "Ultimately", "This highlights the importance of".
- Redundant paraphrase: the same point restated in slightly different words.
- Polished but empty prose: fluent sentences that add little new information.
- Repeated or theatrical "not only X but also Y".
- "Whether you are" constructions aimed at everyone and no one.
- "By doing X, readers/users/organisations can" cadence.
- Excessive hedging paired with grand language.
- Symmetrical three-item lists where the third item feels padded.
- Buzzword stacking: "robust, scalable, innovative, user-centric solution".
- Passive or agentless phrasing that hides who does what.
- Cliched intensifiers: "crucial", "vital", "essential", "pivotal", "key".
- Artificial nuance: "It is not simply X; rather, it is Y".
- Over-coherent flow: every transition is smooth, but the argument lacks real discovery.
- Domain mismatch: fluent terminology but shallow understanding of actual practice.
- False precision or invented-sounding specifics.
- Overuse of "delve", "underscore", "navigate", "unlock", "elevate", "seamless".
- Reassuring filler: "This comprehensive approach ensures".
- Bland inclusivity of all possibilities instead of making an editorial choice.
- Title-case or heading structures that feel template-generated.
- Excessive guide framing: "a comprehensive guide to understanding".
- Repeated cause-effect templates: "This not only improves X but also enhances Y".
- Interrogative titles that are not appropriate in context and are devoid of content, such as "Why this matters".

## Judgement Guidance

Use this filter before keeping any issue:

1. Confirm the passage matches one of the tell categories.
2. Confirm the issue is visible from the excerpt and nearby context.
3. Confirm the wording could reasonably be made more specific, direct, or editorially decisive.
4. Dismiss the issue if the phrase is a domain term, an accurate heading, or a necessary transition.
5. For domain mismatch and false precision, only flag when the document itself supplies enough evidence, for example a technical phrase used fluently but without any operational detail, actor, mechanism, data source, or constraint.

Severity guidance:

- high: repeated pattern that materially weakens credibility, hides responsibility, or makes the section feel templated.
- medium: clear AI-tell pattern that makes a sentence or paragraph generic.
- low: local wording issue worth fixing but not damaging by itself.

Most issues should be medium or low. Use high sparingly.

## Workflow

Throughout, SKILL_DIR means the directory that contains this SKILL.md file.

1. Determine PROJECT_ROOT:

   - If inside a Git repository, set PROJECT_ROOT to the output of:
     git rev-parse --show-toplevel
   - Otherwise, treat the current working directory as PROJECT_ROOT.

2. Determine WORK_DIR:

   - If WORK_DIR was not provided, set it to:
     PROJECT_ROOT/.copyedit_ai_tells

   Create WORK_DIR.

3. Capture the input text into:

   - WORK_DIR/input.txt

   If multiple files are provided, include file boundary markers:
   [FILE: path/to/file.ext]
   ...content...
   [END FILE]

4. Generate candidate issues:

   - Read WORK_DIR/input.txt.
   - Produce only issues that match "Tell Categories".
   - Apply "Judgement Guidance" to each candidate before keeping it.
   - Write filtered issue JSON to:
     WORK_DIR/issues_filtered.json

5. Write outputs:

   If OUTPUT_MODE=json:
   - Write WORK_DIR/issues_filtered.json to OUTPUT_PATH.

   If OUTPUT_MODE=markdown:
   - If OUTPUT_PATH was not provided, set it to:
     PROJECT_ROOT/copyedit_ai_tells_feedback.md
   - Write a concise markdown report grouped by severity, with one issue per finding.

6. Clean version, only if the user explicitly requested it:

   - Write to PROJECT_ROOT/copyedit_ai_tells_clean.md.
   - Preserve meaning and author voice.
   - Make the smallest practical edits to remove kept AI-tell patterns.

7. Confirm completion:

   - Report the output path or state that no matching AI-tell issues were found.
   - Do not paste the entire report in chat unless the user asks.

## Issue Schema

issues_filtered.json must be a JSON array of objects with these fields:

- uid: unique stable id such as ai-tell-001
- mode: must be "ai_tells"
- category: one Tell Categories label
- severity: high, medium, or low
- location: file name plus section or paragraph if possible
- excerpt: short quote, max 20 words, no newlines
- problem: why the wording creates an AI-tell risk, 1 to 3 sentences
- suggestion: minimal concrete fix, 1 to 3 sentences
- discretionary: true for judgement calls, otherwise false
- confidence: high, medium, or low

Do not include fully acceptable passages.
