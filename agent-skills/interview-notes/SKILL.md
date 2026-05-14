---
name: interview-notes
description: "populate research interview note spreadsheets from interview transcripts. use when given a transcript plus an interview guide, project context, research questions, or a spreadsheet/template for notes. extract only concise, important information directly relevant to the research questions; place notes into the best matching spreadsheet cells even when the interview flow diverges from the template; leave cells blank when unsupported."
---

# Interview Notes

## Purpose

Fill an interview-notes spreadsheet from a transcript using the interview guide and project context as the lens for relevance. Prioritize concise, useful notes over exhaustive transcription.

## Required Inputs

Expect some or all of these inputs:

- Interview transcript or transcript excerpts.
- Interview guide, discussion guide, research questions, or project context.
- Spreadsheet, workbook, table, or notes template to populate.

When the spreadsheet is missing, ask for it unless the user explicitly asks for a draft table instead. When context or guide materials are missing, proceed from the transcript and any visible spreadsheet prompts, but note the limitation briefly.

## Workflow

1. **Understand the research frame**
   - Read the project context, research questions, interview guide, and spreadsheet labels before extracting notes.
   - Treat the spreadsheet cells, row labels, column labels, and section headings as the target note structure, not as a strict transcript outline.

2. **Extract relevant information**
   - Focus on information that helps answer the research questions or explains participant attitudes, behaviours, needs, barriers, motivations, decision-making, context, or outcomes.
   - Exclude small talk, filler, repeated statements, moderator setup, off-topic detail, and generic acknowledgements.
   - Do not summarize every question-answer pair. Capture only what is materially useful for the research.

3. **Map notes to the spreadsheet**
   - Put each note into the best available cell based on meaning, even if the actual interview question differed from the spreadsheet prompt.
   - If important information does not perfectly match any cell, place it in the closest relevant cell rather than dropping it.
   - Leave cells blank when the transcript provides no relevant evidence for that prompt.
   - Preserve existing workbook structure, formulas, formatting, sheet names, comments, and unrelated content whenever possible.
   - Do not create new columns, sheets, categories, or major structure unless the user asks or the spreadsheet has nowhere reasonable to capture important findings.

4. **Write concise notes**
   - Use brief phrases, short bullets, or compact sentences.
   - Prefer one to three high-value points per populated cell unless the cell clearly expects more.
   - Keep notes factual and grounded in the participant's words or behaviour.
   - Avoid interpretation that is not supported by the transcript.
   - If the participant is ambiguous, qualify the note, e.g. "seems to...", "unclear whether...", or "may indicate...".

5. **Use verbatim quotes sparingly**
   - Include verbatim quotes only when they are vivid, surprising, emotionally revealing, or especially useful for reporting.
   - Keep quotes short and exact.
   - Do not quote ordinary factual answers when a concise paraphrase is clearer.
   - Use quotation marks for verbatim quotes. Do not invent or clean up quotes beyond obvious transcript artifacts such as repeated filler.

6. **Quality check before returning**
   - Confirm that every populated cell is supported by transcript evidence.
   - Check for overlong cells and trim unnecessary wording.
   - Check that important, pertinent transcript information has not been omitted simply because the interview diverged from the guide.
   - Check that unsupported cells remain blank rather than being filled speculatively.

## Spreadsheet Handling

When editing a spreadsheet file:

- Work directly in the provided workbook and export an updated `.xlsx` unless the user requests another format.
- Preserve the template's layout and formatting.
- Populate only the intended notes areas. Avoid overwriting instructions, formulas, headers, metadata, or existing notes unless the user explicitly asks.
- If multiple sheets or participants are present, identify the correct participant sheet/row from filenames, transcript metadata, sheet labels, or user instructions. If still unclear, make the most reasonable choice and mention it.
- If a cell already contains notes, append or merge carefully rather than replacing useful existing content, unless the task is clearly to regenerate the notes.

## Output Style

- Return the completed spreadsheet as the primary deliverable.
- In the chat response, keep the summary short: mention the file was populated and note any important limitations, such as missing guide/context, unclear participant mapping, or sections left blank because the transcript did not cover them.
- Do not include a long narrative analysis unless the user asks for it.

## Examples of Good Notes

- "Relies on spouse to compare options; wants reassurance before committing."
- "Found the sign-up form easy, but was unsure what happened after submitting."
- "Barrier: assumes the service is only for people in crisis, not early-stage support."
- "Quote: 'I wouldn't know where to start unless someone pointed me there.'"

## Examples to Avoid

- Overly exhaustive: "The interviewer asked about the participant's experience with the website and the participant said that they visited the website last Tuesday and looked around for a few minutes before deciding..."
- Unsupported interpretation: "Participant is resistant to change" when the transcript only says they had not tried the new process.
- Low-value quote: "Yeah, it was fine."
