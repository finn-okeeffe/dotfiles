---
name: process-meeting-transcripts
description: Process one or multiple meeting transcripts into a summary file, following a template.
disable-model-invocation: true
---

# process-meeting-transcripts

## Overview

Given one or more meeting transcript `.txt` files in the **current directory**, create **one** high-quality markdown meeting summary that is **format-stable** (minimal drift) and **grounded** in the transcript(s).

You MUST:
- Write the final markdown to a **new `.md` file in the current directory**.
- Follow the **exact output template** in this skill (headings + tables), located at `assets/meeting-summary-template.md`.
- Produce a **non-empty Participants table** (infer participants from speaker labels/introductions when not explicitly listed).
- Produce an **Actions section as a markdown table** (never bullet points), even if there are zero actions.
- Include **evidence** (timestamps/quotes) for participants and actions to improve accuracy.

If there are multiple transcripts, keep **one output file** and clearly attribute actions/notes to the correct meeting via the `Source transcripts` list and evidence timestamps.

## When to Use

Use this skill when:
- Asked for by the user only.

## Instructions

### 1) Identify transcript files (robustly)
- Consider **all** `.txt` files in the current directory as potential transcripts (do **not** rely on the filename containing `transcript`, since filenames may have typos like `transcipt`).
- Ignore non-transcript files (e.g., `.md` outputs from previous runs) unless the user explicitly asks you to incorporate them.

### 2) Read and validate transcript structure
Transcripts typically look like:
- A small header with recording name/title, meeting date+time, duration
- A line like `X started transcription`
- Speaker turns formatted like: `Full Name   m:ss` or `Full Name   h:mm:ss`

If the format is materially different and you can’t reliably extract speakers/timestamps, ask the user clarifying questions.

### 3) Extract meeting metadata (grounded)
From each transcript header, extract:
- Title (recording name / meeting name)
- Date/time
- Duration
- Organizer/recorder (if present via “started transcription”)
- Purpose (infer from early agenda/context; if unknown, write `Unknown` and explain in Transcript review)

### 4) Build Participants (MUST NOT BE EMPTY)
Because many transcripts do **not** include an explicit attendee list, infer participants using:
- **Speaker labels**: collect all unique names that appear in the `Name   timestamp` pattern.
- **Introductions**: for each participant, capture a 1-sentence background/role if they state it (e.g., “I’m X from Y…”). If not stated, set background/role to `Unknown`.
- **Source**: for each participant row, include a timestamp and short supporting quote, or `inferred from speaker labels` if they never self-introduce.

Rules:
- Do NOT omit participants because their background is unknown.
- Participants should include **everyone who speaks**, plus anyone explicitly named in lines like `X started transcription` / `X stopped transcription` if they are not already captured.
- If you truly cannot infer any names, include one row: `Unknown (not stated)`.

### 5) Write Summary (bullets, grounded)
- Summarize the meeting in concise bullet points.
- Prefer claims that can be supported by the transcript; use timestamps for particularly important points.
- If multiple meetings, group bullets by meeting (or add meeting tags to bullets).

### 6) Extract Actions (MUST BE A MARKDOWN TABLE; NEVER BULLETS)
Identify actions by scanning for:
- Explicit commitments: “I will…”, “I’ll…”, “we will…”, “we’ll…”
- Requests: “could you…”, “please…”
- Next steps / follow-ups: “next steps…”, “follow up…”, “send/share/circulate…”
- Process actions: “I’ll make that change…”, “we should run this again…”, “schedule…”

For each action, include:
- Priority (High/Med/Low; use deadlines/urgency cues)
- Action name (short)
- Owner (person/role; or `Unknown`)
- Deadline (date or `Unknown`)
- Description (1–2 sentences)
- Reasoning (if stated; else `Unknown`)
- Notes (any context/assumptions)
- Evidence (timestamp + short quote)

Rules:
- The Actions section MUST always be a markdown table with a header row and separator row.
- If you find **zero** actions, include a single row with `No actions identified` and explain why in Transcript review.

### 7) Transcript review (required)
After drafting, re-check the transcript(s) and add a short review section:
- Uncertainties / missing info that limited accuracy (e.g., attendees not explicitly listed)
- Likely transcription issues (e.g., name misspellings, overlapping speech)
- Any open questions (only if they materially affect the summary/actions)

### 8) Output file requirement (write `.md` file)
Write the final markdown to a new file in the current directory.

Filename rules:
- If you can confidently parse a meeting date from the transcript header, use: `meeting-summary-YYYY-MM-DD.md`.
- Otherwise use: `meeting-summary.md`.

File creation rules:
- Create the file (do not just describe it).
- Populate it with the full markdown output (exact template shape).
- In your final response, include the saved filename and also paste the same markdown content (so the user can see it immediately).

### 9) Meeting summary template (MUST use)
Use the bundled template at `assets/meeting-summary-template.md`.

Rules:
- Copy the template content **verbatim** (same headings/order/table structure).
- Replace `Unknown` with extracted details when available.
- Do not delete sections. Do not convert tables to bullet points.

### 10) Preflight checklist (MUST pass before finalizing)
- Participants section exists and the table has at least 1 data row.
- Actions section exists and is a markdown table (contains `|` header + separator row).
- No actions are expressed as bullet points.
- Unknown fields are filled with `Unknown` (not omitted).
- High-signal claims/actions have evidence timestamps/quotes.
