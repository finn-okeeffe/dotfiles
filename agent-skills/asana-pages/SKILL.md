---
name: asana-pages
description: Read, find, create, rename and edit Asana Pages (formerly Notes; links like app.asana.com/1/<workspace>/note/<gid>), which the Asana MCP and Asana's public API can't reach. Works through Finn's signed-in browser (Brave, driven by Claude in Chrome) with an in-page script, not screen control. Use when asked to read, summarise, update, add to or tidy an Asana page, or to find or create one.
---

# Asana Pages

Asana Pages (called Notes until 2025) are Asana's documents. They can stand alone or be attached to a project, task, portfolio or team, and they show up under Knowledge > Pages. The Asana MCP has no page tools, and Asana's public API doesn't cover pages, so use Finn's signed-in browser session instead (Brave, which the Claude in Chrome extension drives):

- The web app's own `/api/1.0/notes` endpoints accept the browser session. [scripts/asana_pages.js](scripts/asana_pages.js) uses them to list, create and rename pages.
- Each page is a ProseMirror editor. The script finds the editor behind the open page, reads everything in it (tables, task mentions and formatting included), and applies edits through it. Asana then saves the edits with its own collaborative sync, the same as typing would.

Don't use screen control (computer use) or click through the editor to do this. Use the Asana MCP as usual for tasks, projects and comments.

## Who does the browser work

In Claude Code, hand the browser steps to a Sonnet sub-agent (Agent tool, `model: "sonnet"`, general-purpose) so the script and page dumps stay out of your context. Give it this skill's path, the page link or name, what to do, and a folder in your scratchpad for its files. Ask it to report the file paths, the `show()` results and the check output, not the page text. Then:

1. **Read**: the sub-agent follows "Read a page" below, saves `page.md` and runs the check. Read that file yourself.
2. **Edit**: write the operations to `ops.json` (see "Edit a page"). The sub-agent passes the file's contents to `asanaPages.apply` exactly as written, then saves the page again as `page-after.md`. Diff the two files and check that only the intended blocks changed.

In Codex, or anywhere without sub-agents, do the browser steps yourself with the tool that drives Finn's real browser (Claude in Chrome, or the browser-use plugin).

## Set up the tab

1. Open a new tab at `https://app.asana.com/` (or straight at the page link). Wait until Asana has loaded.
2. Read [scripts/asana_pages.js](scripts/asana_pages.js) and pass its entire contents, unchanged, to the browser tool's JavaScript evaluation. It defines `window.asanaPages`. If a call then says the editor hasn't loaded, wait a few seconds and try again.
3. Run the script again after any full page load. Navigating with the browser tool is a full load; clicking links inside Asana is not.

The JavaScript tool cuts results off at about 1,000 characters, and blocks results containing anything that looks like a URL query string or cookie (even `x = 1`). Return short values (`JSON.stringify` of small objects), and read page content through `show()` as below.

## Find a page

- From a link: page links look like `https://app.asana.com/1/45651789580354/note/<gid>`. Navigate there.
- By name: `await asanaPages.list({query: 'agenda'})` returns `gid | name | last modified` lines, newest first. Use `limit` for more than 30. It covers pages Finn can see in the Scarlatti workspace.
- Asana's search box also finds pages, but `list` is quicker.

## Read a page

1. Navigate to the page, wait for it to load, and run the script.
2. `JSON.stringify(asanaPages.show())` puts the whole page, as Markdown, in a hidden `<article>`. It returns the title, block count, whether Finn can edit it, and the export's `chars` and `lines`.
3. Read it with the browser's page-text tool (`get_page_text` in Claude in Chrome). The tool prints `Title:`, `URL:` and `Source element:` lines, then `---`. The export is everything after that first `---` line, starting at `<!-- page …`, up to the `Tab Context:` block the tool adds at the end.
4. Run `asanaPages.hide()`.
5. To save it, write the export to a file exactly as printed, keeping every `␣` and `⇥`: the page-text tool collapses whitespace, so the script writes leading and repeated spaces as `␣` and tabs as `⇥`. Then decode the file and check it against the counts from `show()`:

   ```bash
   scripts/check_export.sh page.md CHARS LINES
   ```

   The file passes through you as text, so it's easy to merge two lines or drop a character on the way. If the check reports a mismatch, compare the file with the page-text output line by line, fix it, and run the check again (it decodes only `␣` and `⇥`, so running it twice is safe).

The export starts with `<!-- page GID: Title (N blocks) -->`, and each top-level block has a `<!-- block N -->` marker above it. Edits use these block numbers. Pass `{markers: false}` for a clean copy to give Finn, and `{start, end}` for some blocks only.

What the Markdown shows:

- Task, project and other Asana mentions become links to the object, labelled with its name.
- Tables become Markdown tables. The first row becomes the header row, whether or not it is one on the page. Merged cells show as empty cells, with a comment above the table.
- Line breaks within a paragraph show as `<br>`. Empty paragraphs show as a block marker with nothing under it.
- Images show as `![image](asana-asset:ID)`. Embeds and anything else Markdown can't hold show as `{node_type ID}`. Use `show({format: 'json', start, end})` to see their exact ProseMirror JSON. Edits can't create these; keep them by leaving their blocks alone.
- Underline is `<u>`, highlight is `==text==`, and suggested insertions and deletions are `<ins>` and `<del>`. Inline comment threads aren't shown.

## Edit a page

Only edit pages Finn asked you to change, and change only what was asked. Check `editable` from `show()` or `info()` first; read-only pages can't be edited.

Read the page first, then pass all the changes to one `apply` call. Every block number refers to the page as you read it, before any of the operations. `apply` runs them as one change (one undo step in Asana), waits until Asana's server has confirmed it, and returns block counts before and after.

```js
JSON.stringify(await asanaPages.apply([
  {op: 'text', find: 'deferred to 15 October', replace: 'deferred to 29 October'},
  {op: 'replace', start: 4, expect: '23/10', html: '<p><strong>23/10 (updated)</strong></p>'},
  {op: 'insert', at: 2, html: '<h2>Actions</h2><ul><li>Book the venue</li><li>Send the agenda</li></ul>'},
  {op: 'delete', start: 6, end: 8, expect: 'old heading'},
]))
```

| Operation | Fields | Effect |
| --- | --- | --- |
| `text` | `find`, `replace`, `all` (optional) | Replaces exact text. It keeps the replaced text's formatting. `find` must sit within one paragraph, heading, list item or table cell. It fails if the text is missing, or appears more than once without `all: true`. |
| `replace` | `start`, `end` (optional), `expect`, `html` | Replaces blocks `start` to `end - 1`. `end` defaults to `start + 1`, so one block. |
| `insert` | `at`, `html` | Inserts before block `at`. Use the block count to add at the end. |
| `delete` | `start`, `end` (optional), `expect` | Removes blocks `start` to `end - 1`. |

- `expect` is some text from block `start`. The call fails if the block doesn't contain it, so stale block numbers can't change the wrong block. It is required. Use `force: true` only for blocks with no text, such as an empty paragraph or an image.
- Operations may not overlap. A list or a table is one block, so to change one list item use `text`, or replace the whole list.
- Prefer `text` for wording changes. It leaves mentions, comments and formatting around the change alone. Replacing a block rebuilds it, which drops inline comment threads in it.
- `html` goes through the editor's own paste handling, so write the HTML you'd paste. These work: `<p>`, `<h1>` to `<h3>`, `<ul>`/`<ol>`/`<li>` (nest lists for indents), `<table>`/`<tr>`/`<td>`, `<strong>`, `<em>`, `<s>`, `<u>`, `<code>`, `<pre><code>`, `<blockquote>`, `<br>` and `<a href>`. `<hr>` is dropped. Anything else the page doesn't support is dropped or simplified, as when pasting.
- To mention a task or project, link to it: `<a href="https://app.asana.com/1/45651789580354/task/TASK_GID">…</a>` becomes a mention showing the task's name (the link text is not kept).
- Neighbouring lists join up: a `<ul>` straight after an `<ol>` becomes part of the same list block, as it would in the editor.

After applying, read the page again and compare it with the earlier copy. If it went wrong, `await asanaPages.revert()` puts the page back as it was before the last `apply` in that tab. Revert also overwrites anything other people typed since, so use it straight away or not at all. It doesn't survive a page reload.

Don't navigate away or close the tab while `apply` is still waiting; unsaved changes would be lost. If it reports that Asana hasn't confirmed the change, run `await asanaPages.saved()` and look at the page.

If Asana's server rejects a change, the tab shows "Asana needs to be reloaded" and stops syncing; `apply` reports this. Nothing from that `apply` was saved. Run `asanaPages.reload()` (it clicks the dialog's Reload button, which skips the "Leave site?" prompt), wait for the page, run the script again and read the page before trying anything else. Don't navigate or close the tab another way first: the "Leave site?" prompt blocks the browser tools until Finn answers it. If a tab is already stuck behind that prompt, ask Finn to close it and choose Leave, and carry on in a new tab.

## Create or rename a page

- Only create a page when Finn asks for one. `await asanaPages.create('Name')` makes a private page that isn't attached to anything, and returns its `gid` and `url`. Navigate to the URL, run the script again, then add content with `apply` (`insert` at block 0, or `replace` the empty first block with `force: true`).
- `await asanaPages.rename(gid, 'New name')` renames a page.
- Attaching a page to a project or task, sharing it, and deleting it aren't covered. Tell Finn where to do them in Asana (the page's Share and ⋯ menus).

## When something breaks

- `Found the page editor but not its EditorView`: Asana has changed its front end. In the tab, find the element `.ProsemirrorEditor` inside the page and walk its React fiber (`__reactFiber…` key, then `.return`) looking for an object with `dispatch`, `state.doc` and `dom` equal to that element. Update `view()` in the script to match.
- `/api/1.0/notes` errors other than 401: Asana has changed the endpoint. Watch the network requests while doing the same thing in the Asana tab by hand, then update the script.
- HTTP 401 or a sign-in page: Finn needs to sign in to Asana in the browser. Don't enter credentials.
- The page-text tool shows the Asana page instead of the export: `show()` wasn't run after the last page load, or `hide()` already ran.
- A result reads `[BLOCKED: Cookie/query string data]`: the result looked like it held a query string or cookie. Return less (for example, counts or names without links), and read content with `show()` instead.
