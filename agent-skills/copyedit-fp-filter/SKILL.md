---
name: copyedit-fp-filter
description: Evaluate one proposed copy-edit issue and decide whether to keep it or dismiss it as a false positive or nitpick, preserving author intent and NZ English conventions. Designed for multi-agent workflows where each sub-agent reviews exactly one issue and outputs exactly one JSON decision file.
---

# False-positive and nitpick filter (single issue, single decision file)

Purpose: evaluate exactly one candidate issue from a copy-edit pass and decide whether it should remain in the final report.

This skill is intentionally narrow. It must never be used to process a list of issues, run a pipeline step, or generate multiple decision files.

## Hard rules

1. Exactly one issue. Evaluate only the provided ISSUE object. Do not add new issues. Do not process multiple issues.
2. Exactly one decision file. When OUTPUT_MODE=json, write exactly one JSON object to OUTPUT_PATH. Do not write any other files.
3. No delegation. Do not spawn or delegate to other agents. This agent is the decision maker for this one issue.
4. Write in New Zealand English. Do not output em dashes or en dashes (Unicode U+2014 and U+2013). Use commas, parentheses, or hyphens instead.
5. Do not fact-check with outside sources unless the caller explicitly permits it (normally not permitted in this filter step).

## Inputs

The caller should provide:

- ISSUE: a single issue object (JSON)
- CONTEXT: enough of the original text to judge the issue

Optional caller parameters:

- OUTPUT_MODE: json (default) or markdown
- OUTPUT_PATH: required when OUTPUT_MODE=json

## Anti-batching guard

If the prompt includes batch instructions (for example, "process all remaining issues", "generate one decision file per uid", or "run step 6"), treat that as invalid for this skill.

You must still produce exactly one decision for exactly one issue:

- Prefer the explicit ISSUE object.
- If ISSUE is accidentally provided as a list, use only the first element.
- In the reason field, add: "Processed one issue only. Run one sub-agent per issue.".

## Decision criteria

Dismiss the issue when any of the following holds:

- The issue is a misread of the text (false positive).
- The suggested change is wrong, introduces ambiguity, or changes meaning.
- The issue is a micro-tweak with negligible readability benefit.
- The issue duplicates another, higher-quality issue already present (only if the caller indicates this).
- The suggestion violates constraints (for example, introduces forbidden dash characters).

Keep the issue when it is clearly beneficial:

- It fixes an objective error (spelling, grammar, unit formatting, wrong term).
- It reduces genuine ambiguity or improves clarity materially.
- It resolves a logical inconsistency, unsupported claim, or denominator or unit mismatch.
- It prevents misinterpretation by tightening scope or modality.

If the issue is valid but the suggested fix is too heavy-handed, keep it but provide a revised, minimal suggestion in issue_patch.

## Output (OUTPUT_MODE=json)

Write a single JSON object to OUTPUT_PATH with this shape:

{
  "uid": "<issue uid>",
  "decision": "keep" | "dismiss",
  "reason": "<short justification>",
  "issue_patch": { ... }
}

Rules:

- Always include uid, decision, and reason.
- Only include issue_patch when decision is keep and you need to adjust severity, problem, suggestion, discretionary, or confidence.
- Do not output any non-JSON text when OUTPUT_MODE=json.

## Output (OUTPUT_MODE=markdown)

Return a short decision statement, plus (if keeping) a revised minimal suggestion. Keep it brief.
