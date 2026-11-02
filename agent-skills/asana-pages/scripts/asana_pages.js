// Run in an app.asana.com tab signed in to Finn's account. Defines window.asanaPages.
// Asana Pages (formerly Notes) aren't in the public API or the Asana MCP. This uses what the web app itself uses:
// - the /api/1.0/notes endpoints, which accept the browser session, to list, create and rename pages;
// - the open page's ProseMirror editor, to read everything on the page (tables and mentions included) and to edit it.
//   Edits go through the editor, so Asana saves them with its own collaborative sync.
window.asanaPages = (() => {
  const HEADERS = { 'X-Allow-Asana-Client': '1', 'Content-Type': 'application/json' };
  const EXPORT_ID = 'asana-pages-export';
  const MARKS = {
    bold: ['**', '**'], italic: ['*', '*'], strike: ['~~', '~~'], code: ['`', '`'], underline: ['<u>', '</u>'],
    highlight: ['==', '=='], suggestion_insert: ['<ins>', '</ins>'], suggestion_delete: ['<del>', '</del>'],
  };
  let snapshot = null;

  async function api(method, path, data) {
    const response = await fetch(`/api/1.0${path}`, {
      method,
      credentials: 'include',
      headers: HEADERS,
      body: data ? JSON.stringify({ data }) : undefined,
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(`${method} ${path.split('?')[0]} failed: HTTP ${response.status} ${JSON.stringify(body.errors || '')}`);
    }
    return body;
  }

  function workspaceGid() {
    const match = location.pathname.match(/^\/\d+\/(\d+)(\/|$)/);
    if (!match) throw new Error('Open app.asana.com and wait for it to load; the URL has no workspace ID yet.');
    return match[1];
  }

  function pageGid() {
    return location.pathname.match(/\/note\/(\d+)/)?.[1] || null;
  }

  function pageUrl(gid) {
    return `${location.origin}/1/${workspaceGid()}/note/${gid}`;
  }

  // One line per page: gid | name | last modified. `query` filters names (case-insensitive).
  async function list({ query = '', limit = 30 } = {}) {
    const wanted = query.toLowerCase();
    const lines = [];
    let offset = null;
    do {
      const params = new URLSearchParams({ workspace: workspaceGid(), limit: '100', opt_fields: 'name,modified_at' });
      if (offset) params.set('offset', offset);
      const body = await api('GET', `/notes?${params}`);
      for (const page of body.data) {
        const name = page.name || 'Untitled Page';
        if (!wanted || name.toLowerCase().includes(wanted)) {
          lines.push(`${page.gid} | ${name} | ${(page.modified_at || '').slice(0, 10)}`);
        }
      }
      offset = body.next_page?.offset;
    } while (offset && lines.length < limit);
    return lines.slice(0, limit).join('\n') || 'No matching pages';
  }

  // Creates a private, unattached page. Returns its gid and URL.
  async function create(name) {
    const body = await api('POST', '/notes', { workspace: workspaceGid(), name });
    return { gid: body.data.gid, url: pageUrl(body.data.gid) };
  }

  async function rename(gid, name) {
    const body = await api('PUT', `/notes/${gid}`, { name });
    return { gid, name: body.data?.name };
  }

  function editorElement() {
    return document.querySelector('.DocumentLayout-content .ProsemirrorEditor') || document.querySelector('.ProsemirrorEditor');
  }

  // The ProseMirror EditorView behind the open page.
  function view() {
    if (!pageGid()) throw new Error('Open the page first: https://app.asana.com/1/<workspace>/note/<gid>');
    const element = editorElement();
    if (!element) throw new Error('The page editor has not loaded yet. Wait a few seconds and try again.');
    const key = Object.keys(element).find((name) => name.startsWith('__reactFiber'));
    for (let fiber = element[key]; fiber; fiber = fiber.return) {
      const candidate = fiber.stateNode?._pmStateManager?._initialStateOrEditorView;
      if (candidate?.dispatch && candidate.dom === element) return candidate;
    }
    throw new Error('Found the page editor but not its EditorView. Asana may have changed its front end; see SKILL.md.');
  }

  function title() {
    return document.title.replace(/^●\s*/, '').replace(/\s*-\s*Asana$/, '');
  }

  function unconfirmedSteps(v) {
    return v.state['collab$']?.unconfirmed?.length ?? null;
  }

  function info() {
    const v = view();
    return {
      gid: pageGid(),
      title: title(),
      blocks: v.state.doc.childCount,
      editable: v.editable,
      unsavedChanges: unconfirmedSteps(v),
      syncStopped: crashed(),
      revertAvailable: snapshot?.gid === pageGid(),
    };
  }

  // Markdown conversion. `pos` is always the document position just before `node`.

  function absolute(href) {
    try {
      return new URL(href, location.origin).href;
    } catch {
      return href;
    }
  }

  function wrap(text, before, after) {
    const [, lead, core, trail] = text.match(/^(\s*)([\s\S]*?)(\s*)$/);
    return core ? lead + before + core + after + trail : text;
  }

  function inlineMarkdown(v, block, pos, inTable) {
    let out = '';
    block.forEach((child, offset) => {
      const at = pos + 1 + offset;
      const name = child.type.name;
      let text;
      if (child.isText) {
        text = inTable ? child.text.replace(/\|/g, '\\|') : child.text;
        for (const mark of child.marks) {
          const pair = MARKS[mark.type.name];
          if (pair) text = wrap(text, pair[0], pair[1]);
        }
        const link = child.marks.find((mark) => mark.type.name === 'link');
        if (link) text = `[${text}](${absolute(link.attrs.href)})`;
      } else if (name === 'line_break') {
        text = '<br>';
      } else if (name === 'asana_object') {
        const label = child.attrs.title || v.nodeDOM(at)?.textContent?.trim() || `Asana object ${child.attrs.object_id}`;
        text = `[${label}](${absolute(child.attrs.preferred_path || `/0/0/${child.attrs.object_id}`)})`;
      } else if (name === 'app_link') {
        text = `[${v.nodeDOM(at)?.textContent?.trim() || 'link'}](${absolute(child.attrs.href)})`;
      } else {
        text = `{${name}${child.attrs.object_id ? ` ${child.attrs.object_id}` : ''}}`;
      }
      out += text;
    });
    return out;
  }

  function childBlocks(v, node, pos) {
    const out = [];
    node.forEach((child, offset) => out.push(blockMarkdown(v, child, pos + 1 + offset)));
    return out;
  }

  function listMarkdown(v, list, pos) {
    const counters = [];
    const lines = [];
    list.forEach((item, offset) => {
      const depth = Math.max(0, (item.attrs.indent || 1) - 1);
      counters.length = depth + 1;
      counters[depth] = (counters[depth] || 0) + 1;
      const type = item.attrs.type;
      // Asana joins neighbouring lists into one, so a bullet between numbered items restarts the numbering.
      if (type !== 'numbered') counters[depth] = 0;
      const marker = type === 'numbered' ? `${counters[depth]}.` : type === 'bulleted' ? '-' : `- [${type}]`;
      const pad = '    '.repeat(depth);
      const body = childBlocks(v, item, pos + 1 + offset).join('\n');
      lines.push(`${pad}${marker} ${body.split('\n').join(`\n${pad}${' '.repeat(marker.length + 1)}`)}`);
    });
    return lines.join('\n');
  }

  function tableMarkdown(v, table, pos) {
    const rows = [];
    let merged = false;
    table.forEach((row, rowOffset) => {
      const cells = [];
      row.forEach((cell, cellOffset) => {
        const cellPos = pos + 1 + rowOffset + 1 + cellOffset;
        const parts = [];
        cell.forEach((child, offset) => {
          const at = cellPos + 1 + offset;
          parts.push(child.type.name === 'paragraph'
            ? inlineMarkdown(v, child, at, true)
            : blockMarkdown(v, child, at).replace(/\|/g, '\\|'));
        });
        cells.push(parts.join('<br>').replace(/\n/g, '<br>'));
        const span = cell.attrs.colspan || 1;
        if (span > 1 || (cell.attrs.rowspan || 1) > 1) merged = true;
        for (let i = 1; i < span; i++) cells.push('');
      });
      rows.push(cells);
    });
    const width = Math.max(...rows.map((cells) => cells.length));
    const lines = rows.map((cells) => `| ${[...cells, ...Array(width - cells.length).fill('')].join(' | ')} |`);
    lines.splice(1, 0, `|${' --- |'.repeat(width)}`);
    if (merged) lines.unshift('<!-- this table has merged cells; Markdown shows them as empty cells -->');
    return lines.join('\n');
  }

  function blockMarkdown(v, node, pos) {
    switch (node.type.name) {
      case 'paragraph':
        return inlineMarkdown(v, node, pos, false);
      case 'header': {
        const level = parseInt(String(node.attrs.level).replace(/\D/g, ''), 10) || 1;
        return `${'#'.repeat(level)} ${inlineMarkdown(v, node, pos, false)}`;
      }
      case 'blockquote':
        return childBlocks(v, node, pos).map((text) => text.split('\n').map((line) => `> ${line}`).join('\n')).join('\n>\n');
      case 'code_block': {
        // Asana separates code lines with line_break nodes, which textContent leaves out.
        let code = '';
        node.forEach((child) => { code += child.isText ? child.text : '\n'; });
        return `\`\`\`${node.attrs.language || ''}\n${code}\n\`\`\``;
      }
      case 'horizontal_rule':
        return '---';
      case 'list':
        return listMarkdown(v, node, pos);
      case 'table':
        return tableMarkdown(v, node, pos);
      case 'img':
        return `![image](asana-asset:${node.attrs.asset_id})`;
      default: {
        const id = node.attrs.object_id || node.attrs.project_id || node.attrs.chart_embed_id || node.attrs.asset_id;
        return `{${node.type.name}${id ? ` ${id}` : ''}}`;
      }
    }
  }

  function render(v, { format, start, end, markers }) {
    const out = [`<!-- page ${pageGid()}: ${title()} (${v.state.doc.childCount} blocks) -->`];
    v.state.doc.forEach((node, offset, index) => {
      if (index < start || index >= end) return;
      if (markers) out.push(`<!-- block ${index} -->`);
      out.push(format === 'json' ? JSON.stringify(node.toJSON()) : blockMarkdown(v, node, offset));
    });
    return out.join('\n\n');
  }

  // Puts the page (as Markdown, or as ProseMirror JSON) in a hidden <article> for the browser tool's
  // page-text reader, which returns it in full. Read it, then call hide().
  // That reader collapses whitespace, so leading and repeated spaces come out as ␣ and tabs as ⇥.
  function show({ format = 'markdown', start = 0, end = Infinity, markers = true } = {}) {
    const v = view();
    hide();
    const article = document.createElement('article');
    article.id = EXPORT_ID;
    article.style.cssText = 'position:fixed;left:0;top:0;width:10px;height:10px;overflow:hidden;opacity:0.01;z-index:-1;pointer-events:none';
    const pre = document.createElement('pre');
    const text = render(v, { format, start, end, markers });
    pre.textContent = text.replace(/^ +| {2,}/gm, (spaces) => '␣'.repeat(spaces.length)).replace(/\t/g, '⇥');
    article.appendChild(pre);
    document.body.appendChild(article);
    // A saved and decoded copy should have the same counts; check_export.sh compares them.
    return { ...info(), chars: [...text].length, lines: text.split('\n').length, next: 'Read it with the page-text tool, then call asanaPages.hide()' };
  }

  function hide() {
    document.getElementById(EXPORT_ID)?.remove();
    return 'hidden';
  }

  // Editing.

  function blockRanges(doc) {
    const ranges = [];
    doc.forEach((node, offset) => ranges.push({ from: offset, to: offset + node.nodeSize, node }));
    return ranges;
  }

  // Parses HTML with the editor's own paste handling, so the result matches what pasting it would produce.
  function parseHtml(v, html) {
    let firstParagraph = null;
    v.state.doc.forEach((node, offset) => {
      if (firstParagraph === null && node.type.name === 'paragraph') firstParagraph = offset + 1;
    });
    // Parse with the cursor in a top-level paragraph: inside a code block or table cell, pasted HTML is handled differently.
    if (firstParagraph !== null) {
      const selection = v.state.selection.constructor.near(v.state.doc.resolve(firstParagraph));
      v.dispatch(v.state.tr.setSelection(selection).setMeta('addToHistory', false));
    }
    let slice = null;
    const previous = v.props.handlePaste;
    v.setProps({ handlePaste: (_view, _event, parsed) => { slice = parsed; return true; } });
    try {
      v.pasteHTML(html);
    } finally {
      v.setProps({ handlePaste: previous });
    }
    if (!slice) throw new Error('The editor did not parse the HTML.');
    return slice.content;
  }

  // Content always goes through the editor's paste handling. Asana's server rejects some hand-built nodes
  // (a task mention without its path, for one), and a rejected change stops the tab syncing.
  function contentFor(v, op, label) {
    if (typeof op.html !== 'string') throw new Error(`${label}: give the new content as html.`);
    return parseHtml(v, op.html);
  }

  function findText(doc, find) {
    const hits = [];
    doc.descendants((node, pos) => {
      if (!node.isTextblock) return true;
      let text = '';
      const positions = [];
      node.forEach((child, offset) => {
        const start = pos + 1 + offset;
        if (child.isText) {
          for (let i = 0; i < child.text.length; i++) positions.push(start + i);
          text += child.text;
        } else {
          positions.push(start);
          text += '\ufffc';
        }
      });
      for (let i = text.indexOf(find); i !== -1; i = text.indexOf(find, i + find.length)) {
        hits.push({ from: positions[i], to: positions[i + find.length - 1] + 1 });
      }
      return false;
    });
    return hits;
  }

  function checkExpect(range, op, label, index) {
    if (op.force) return;
    if (typeof op.expect !== 'string' || !op.expect) {
      throw new Error(`${label}: add expect (some text from block ${index}) so a stale block number can't change the wrong block.`);
    }
    if (!range.node.textContent.includes(op.expect)) {
      throw new Error(`${label}: block ${index} does not contain ${JSON.stringify(op.expect)}. Re-read the page; block numbers may have changed.`);
    }
  }

  // Works out each operation's document range against the unedited page.
  function plan(v, ops) {
    const doc = v.state.doc;
    const ranges = blockRanges(doc);
    const steps = [];
    ops.forEach((op, i) => {
      const label = `op ${i} (${op.op})`;
      if (op.op === 'replace' || op.op === 'delete') {
        const start = op.start;
        const end = op.end ?? start + 1;
        if (!(Number.isInteger(start) && Number.isInteger(end) && start >= 0 && end > start && end <= ranges.length)) {
          throw new Error(`${label}: blocks ${start} to ${end} are outside 0 to ${ranges.length}.`);
        }
        checkExpect(ranges[start], op, label, start);
        steps.push({
          label,
          from: ranges[start].from,
          to: ranges[end - 1].to,
          content: op.op === 'replace' ? contentFor(v, op, label) : null,
        });
      } else if (op.op === 'insert') {
        if (!(Number.isInteger(op.at) && op.at >= 0 && op.at <= ranges.length)) {
          throw new Error(`${label}: at must be 0 to ${ranges.length} (${ranges.length} appends).`);
        }
        const at = op.at === ranges.length ? doc.content.size : ranges[op.at].from;
        steps.push({ label, from: at, to: at, content: contentFor(v, op, label) });
      } else if (op.op === 'text') {
        if (typeof op.find !== 'string' || !op.find || typeof op.replace !== 'string') {
          throw new Error(`${label}: give find and replace as strings.`);
        }
        const hits = findText(doc, op.find);
        if (hits.length === 0) throw new Error(`${label}: ${JSON.stringify(op.find)} is not on the page (text must sit within one paragraph, heading, list item or cell).`);
        if (hits.length > 1 && !op.all) {
          throw new Error(`${label}: ${JSON.stringify(op.find)} occurs ${hits.length} times. Use a longer find, or all: true.`);
        }
        for (const hit of hits) steps.push({ label, ...hit, text: op.replace });
      } else {
        throw new Error(`${label}: op must be replace, insert, delete or text.`);
      }
    });
    const sorted = [...steps].sort((a, b) => a.from - b.from || a.to - b.to);
    for (let i = 1; i < sorted.length; i++) {
      if (sorted[i].from < sorted[i - 1].to) throw new Error(`${sorted[i - 1].label} and ${sorted[i].label} overlap. Combine them.`);
    }
    return steps;
  }

  function crashed() {
    return Boolean(document.querySelector('[class*="errorModal"]'));
  }

  // Clicks Reload in Asana's "Asana needs to be reloaded" dialog. Unconfirmed changes in this tab are lost.
  function reload() {
    const button = [...document.querySelectorAll('[class*="errorDialogButton"]')].find((element) => element.textContent.trim() === 'Reload');
    if (!button) return 'No reload dialog showing';
    button.click();
    return 'Reloading; wait for the page, then run the script again';
  }

  // Waits until Asana's server has confirmed every change made in this tab.
  async function saved(timeoutSeconds = 30) {
    const v = view();
    const deadline = Date.now() + timeoutSeconds * 1000;
    while (Date.now() < deadline) {
      if (crashed()) {
        throw new Error('Asana rejected the change and stopped syncing this tab, so the change was not saved. Run asanaPages.reload(), then read the page again.');
      }
      const pending = unconfirmedSteps(v);
      if (pending === null) return 'unknown (no collaboration state found)';
      if (pending === 0) return 'saved';
      await new Promise((resolve) => setTimeout(resolve, 300));
    }
    throw new Error(`Asana has not confirmed ${unconfirmedSteps(v)} change(s) after ${timeoutSeconds}s. Stay on the page and check it.`);
  }

  // Applies all operations as one change (one undo step in Asana). Block numbers refer to the page before any of them.
  //   {op: 'replace', start, end?, expect, html}   blocks start..end-1 (end defaults to start + 1)
  //   {op: 'insert', at, html}                      before block `at`; at = block count appends
  //   {op: 'delete', start, end?, expect}
  //   {op: 'text', find, replace, all?}                     keeps the formatting of the replaced text
  async function apply(ops) {
    const v = view();
    if (crashed()) throw new Error('Asana has stopped syncing this tab. Run asanaPages.reload() first.');
    if (!v.editable) throw new Error('You can only view this page, not edit it.');
    if (unconfirmedSteps(v)) await saved();
    const before = v.state.doc;
    const steps = plan(v, ops);
    const tr = v.state.tr;
    for (const step of steps) {
      const from = tr.mapping.map(step.from, 1);
      const to = Math.max(from, tr.mapping.map(step.to, -1));
      if ('text' in step) {
        if (step.text) tr.insertText(step.text, from, to);
        else tr.delete(from, to);
      } else if (step.content) {
        tr.replaceWith(from, to, step.content);
      } else {
        tr.delete(from, to);
      }
    }
    if (tr.doc.childCount === 0) tr.insert(0, v.state.schema.nodes.paragraph.create());
    snapshot = { gid: pageGid(), doc: before };
    v.dispatch(tr.scrollIntoView());
    const status = await saved();
    return { status, steps: steps.length, blocksBefore: before.childCount, blocksAfter: v.state.doc.childCount };
  }

  // Puts the page back as it was before the last apply() in this tab. It also undoes anyone else's edits made since.
  async function revert() {
    const v = view();
    if (snapshot?.gid !== pageGid()) throw new Error('Nothing to revert on this page in this tab.');
    v.dispatch(v.state.tr.replaceWith(0, v.state.doc.content.size, snapshot.doc.content));
    snapshot = null;
    return saved();
  }

  return { list, create, rename, info, show, hide, apply, saved, revert, reload, view };
})();
window.asanaPages.info ? (location.pathname.includes('/note/') ? 'asanaPages ready on a page' : 'asanaPages ready; open a page to read or edit it') : 'failed';
