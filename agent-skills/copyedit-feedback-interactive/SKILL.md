---
name: copyedit-feedback-interactive
description: Run a stateful, one-by-one copyedit resolution workflow from copyedit feedback reports (for example copyedit_feedback.md or copyedit_*_feedback.md). Use when the user wants each issue reviewed interactively with surrounding source context, explicit decision options (apply edit, skip, create Asana task, and from item 2 onward revert previous change), and immediate execution without subagents.
---

# Copyedit Feedback Interactive

## Overview

Process kept copyedit issues in order, ask for a decision on each issue, and execute the chosen action immediately. Track progress in a state file so the workflow can resume after interruptions and can safely support "revert previous change, then return to current item".

## Non-Negotiable Requirements

Follow these rules exactly:

- Work item-by-item through the feedback file in order.
- Immediately before asking for a decision on an item, print:
  1) the surrounding context from the source document (paragraph or closest equivalent),
  2) the full feedback block for that item.
- Always include a "skip to next (do nothing)" option.
- Always include a "create Asana task for later" option.
- From the second item onward, always include a dedicated "revert previous change and do previous item differently" option.
- Never merge the revert option into any other option.
- If the user chooses revert previous change:
  1) undo/repair the previous action according to action type,
  2) solicit what to do differently for that previous item,
  3) execute the new choice,
  4) return to the current (not yet addressed) item.
- Execute actions yourself. Do not spawn subagents.

## Inputs

- A copyedit feedback report, usually `copyedit_feedback.md`, but also accept similar names such as `copyedit_*_feedback.md`.
- The source document(s) referenced by `Location:` lines in each item.
- A progress-state file in repo root:
  - `.copyedit_progress_state.json`

## Files in This Skill

- `scripts/extract_kept_issues.py`: Parse kept issues from a feedback markdown file into ordered JSON.

## Workflow

### 1) Detect feedback file

Use this priority:
1. `copyedit_feedback.md` if present.
2. Most likely `copyedit_*_feedback.md` match.
3. Ask user to confirm file path if ambiguous.

### 2) Build deterministic issue queue

Run:

```bash
python3 scripts/extract_kept_issues.py --input <feedback-file> --output /tmp/copyedit_kept_issues.json
```

If no kept issues are found, stop and report that there is nothing to process.

### 3) Load or initialize state

Use `.copyedit_progress_state.json` with this shape:

```json
{
  "source": "copyedit_feedback.md",
  "current_item": "Comment 1 (GEN-0007)",
  "completed": [],
  "history": []
}
```

`history` entries must record action type and enough data to reverse it:
- File edit:
  - `action_type: "file_edit"`
  - `item`
  - `file`
  - `before_text`
  - `after_text`
- Asana task:
  - `action_type: "asana_task"`
  - `item`
  - `task_gid`
  - `task_name`
- Skip:
  - `action_type: "skip"`
  - `item`

### 4) For each item, print context and full feedback first

For each unresolved item:
1. Parse `Location:` to get file and line if available.
2. Print surrounding source context from that file (paragraph preferred; fallback to +/- 8 lines around location line).
3. Print the full feedback block exactly as captured by the parser.
4. If rewrite is moderate/substantial, print proposed full revised text before asking for a decision.

Moderate/substantial rewrite heuristic:
- Any proposed replacement that rewrites more than one sentence, changes argument structure, or exceeds roughly 20 words of net edit.
- If unsure, treat as moderate and show full revision.

### 5) Ask decision for current item

Preferred: call `request_user_input` for every item if the tool is available in the current collaboration mode.
Fallback: ask directly in chat with numbered options when `request_user_input` is unavailable.

Decision options (always include all that apply):
1. Apply proposed edit now.
2. Skip and move to next item (no changes).
3. Create Asana task for later (describe the problem only, not suggested fix).
4. (Item 2 onward only) Revert previous change and redo previous item differently.

### 6) Execute selected option immediately

#### Option 1: Apply edit

- Make the document edit.
- Verify the edit landed at the intended place.
- Add `history` record with reversible data (`before_text` and `after_text`).
- Mark item completed and move forward.

#### Option 2: Skip

- Record skip in `history`.
- Mark item as skipped in `completed`.
- Move forward.

#### Option 3: Create Asana task

- Only use Asana if user selected this option.
- Before task creation, read `AGENTS.md` in the working repo for workspace/project constraints.
- Create task with issue/problem only. Do not include suggested rewrite text.
- Record `task_gid` in `history`.
- Mark item as deferred in `completed`.
- Move forward.

#### Option 4: Revert previous change (separate option, never merged)

1. Inspect last `history` action.
2. Undo according to type:
   - `file_edit`: restore `before_text` in `file`.
   - `asana_task`: edit/close/delete or otherwise repair the task state as directed by user intent.
   - `skip`: remove skip mark.
3. Ask user what to do differently for that previous item.
4. Execute that new choice and store new history entry.
5. Return to the current item and continue. Do not skip it.

### 7) Resume behavior

At start of each turn, inspect `.copyedit_progress_state.json` before continuing.
Do not assume previous action type; verify from `history`.

## Output Format for Each Item

Before asking decision, print sections in this order:
1. `Current item`
2. `Source context`
3. `Full feedback`
4. `Proposed full revision` (only when moderate/substantial)
5. `Decision options`

## Safety and Quality Checks

- Never run destructive git commands.
- Never use sudo.
- Do not commit or push unless user explicitly asks in their most recent message.
- If feedback location is missing/invalid, report the gap and ask whether to skip, patch manually, or create Asana task.
