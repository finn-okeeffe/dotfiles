---
name: create-asana-tasks
description: Create Asana tasks and subtasks from a user request, then present saved details in tables with notes and comments in block quotes. Use when asked to add tasks to Asana, including subtasks under new or existing parents.
---

# Create Asana tasks

Create the requested tasks, then show the user what was saved. Do not add an agent review step or a routine approval pause. If the user specifically requests a draft or approval before creation, honour that request.

## Create tasks

- Discover the available Asana tools and read their current arguments. Use the direct creation tool (`asana_create_tasks` in the current connector); use a preview tool only when the user asks for a preview or confirmation before creation.
- Use the request and conversation to determine the task title, description, project, section, assignee, dates, and any other requested fields. Look up referenced Asana objects when their IDs or details are missing. Ask only when necessary information remains unclear after lookup; do not invent assignments or deadlines.
- Write a clear, actionable title and enough description to carry out the requested work. Preserve supplied requirements and links. Leave unspecified optional fields unset; a project or assignee required by the connector is not permission to choose an arbitrary one.
- Create only the requested tasks and subtasks. Use the returned parent ID when adding children to a new task; read an existing parent when needed to establish its identity and context.
- Add comments only when the user requests them. Use task notes for the description and the comment tool for requested human discussion or context. Do not post agent review notes or duplicate automatic activity such as assignment changes.

## Keep subtasks under their parent

Subtasks must not be added as separate entries in any project's main list. Assigned subtasks may still appear in the assignee's My Tasks.

- Set each subtask's `parent` to its immediate parent's ID. Do not set `project_id` or `section_id`, or add the subtask to a project in a later call.
- Create subtasks separately from parent tasks and any batch using `default_project`. Omission of a per-task project does not cancel the batch's default project.
- Do not inherit an assignee or date from the parent unless the user asked for that. A batch's `default_assignee` is suitable only when that assignment is intended for every task in the batch.
- The current `asana_create_tasks` tool documents a requirement for either `default_project` or `default_assignee`. For subtasks with an intended assignee, use a separate batch with that `default_assignee` and no project. If the available tool cannot create a requested unassigned subtask without a project, report that limitation and ask for the missing decision. Do not assign it merely to satisfy the tool or temporarily add it to a project.
- Distinguish the parent's project context from the subtask's own project membership when reporting results. Parent context does not mean the child was separately added to that project.

See [Asana's object hierarchy](https://developers.asana.com/docs/object-hierarchy) for the distinction between a task's parent and its project membership. Follow the current connector's documented arguments rather than assuming unsupported parameters exist.

## Handle results

- Keep successful task IDs and links. If a batch partly fails, present the successful tasks and state which requested items remain uncreated or incomplete, with the returned reasons.
- Retry only operations known to have failed without creating the item. If a response is missing or the outcome is uncertain, look up the task before retrying; do not repeat the whole batch and risk duplicates. Report an unresolved outcome instead of continuing blind retries.
- Use creation responses to populate the presentation below. Fetch saved task details or comments only when needed to fill missing information. This is reporting saved values, not an editorial review or a reason to rewrite the task.
- Do not claim a value was saved unless the tool result supports it. Distinguish an empty field from unavailable information. If creation succeeded but a details fetch failed, show the known details and label the rest “Unavailable”.

## Present each created task

Show one block per task, with its subtasks immediately following it, in parent-first order. Use the following format, replacing the example values with saved values. Include additional fields set during creation as extra table rows. Use readable names and dates, and returned task links when available; use an ID if a link is unavailable.

| Detail | Value |
| --- | --- |
| Task | Linked task title |
| Parent | Linked parent, or “None” |
| Project / section | Actual membership, or “None” |
| Assignee | Name, or “Unassigned” |
| Start / due date | Dates, or “Not set” for each unset date |
| Status | Saved completion or approval status, as applicable |

**Notes**

> Saved task description, or “None”.

**Comments**

> Saved comment text, with author when available, or “None”.

Keep notes and comments below the table, never inside table cells. Preserve their wording, paragraph breaks, lists, and links; convert stored rich text to readable Markdown rather than showing raw HTML. Prefix every line of each quoted block with `>`, including blank lines. Put each comment in its own block quote with the author when available. Do not silently truncate comments: retrieve additional pages when supported or state when the tool returns only a limited set. Escape pipes and flatten line breaks in table values so task titles and other fields cannot break the table.

Use “None” for comments only when the returned data establishes there are none; otherwise fetch them or say “Unavailable”. Do not ask the user to approve tasks that have already been created.
