---
name: noun-project-icons
description: Find, choose, and download icons from The Noun Project (thenounproject.com) on Finn's Icon Pro account, as recoloured SVG or PNG files saved straight into a WSL folder with a licence record. Use when asked for Noun Project icons, or for icons to put in a document, deck, chart, diagram, or web page where a Noun Project icon would suit.
---

# Noun Project icons

Finn has a Noun Project **Icon Pro** subscription. Icons downloaded while signed in to that account come with a royalty-free licence: no attribution needed, and colour, background, rotation and flip can be set before download. Finn's Pro plan does not include the paid Noun Project API, so do everything through Finn's signed-in Chrome session.

The site's download buttons open a Windows Save As dialog, so don't use them. Instead, run the site's own GraphQL calls from inside the page. The page then submits the files as a form to a small receiver on WSL localhost. The receiver saves them and sends the tab back to Noun Project. No dialogs, no Downloads folder.

## 1. Open the site and check the account

1. Use the browser tool that drives Finn's real Chrome (Claude in Chrome in Claude Code, or the browser-use plugin in Codex). Open `https://thenounproject.com/` in a new tab.
2. Run the whole of [scripts/noun_page.js](scripts/noun_page.js) in the page with the tool's JavaScript evaluation. It defines `window.nounIcons` and returns `{signedIn, iconPro, creatorPro}`.
3. If `signedIn` or `iconPro` is false, stop and tell Finn. Don't download without Pro: the licence would be Creative Commons with attribution required, not royalty-free.

Run `noun_page.js` again after any page load, including the automatic return after each download batch.

## 2. Search and choose

```js
const r = await nounIcons.search('dairy cow', {style: 'line', limit: 25});
r.total + '\n' + r.icons.map(i => `${i.id} ${i.title} / ${i.creator}`).join('\n')
```

- `style` is `'line'`, `'solid'`, or both as an array. Page through results with `offset`.
- The browser tool cuts off output at about 1,000 characters, so return one compact line per icon and keep `limit` to about 25 per call.
- Try synonyms and narrower terms when results are weak. Icons from the same creator or icon set usually match in style, so for a set of icons, prefer one creator.

To choose by eye, build a labelled contact sheet from public thumbnails and view it as an image:

```sh
scripts/contact_sheet.sh /path/to/sheet.png 8245057 7513764 7509087 ...
```

Unless Finn has already picked the icons, show Finn the shortlist (contact sheet plus IDs) before downloading a large set. For one or two obvious icons, go ahead.

## 3. Download

1. Decide where the files go: the folder Finn names, or else `./icons/` in the current project. Don't write into SharePoint or a SharePoint-linked folder without Finn's permission. Avoid OneDrive or Nextcloud folders unless Finn asks for one.
2. Start the receiver as a background process and read its first output line for the `receiver` URL (it contains a random token):

   ```sh
   uv run --no-project scripts/receive_icons.py OUT_DIR --batches 1
   ```

   Use `--port` if 8765 is taken. Without `--batches` it keeps running until 15 minutes pass with no batch.
3. Send all icons in one call. The page fetches every file first, then submits them together:

   ```js
   JSON.stringify(await nounIcons.send(RECEIVER_URL, [
     {id: '7513764', format: 'svg', color: '#1B6E8C'},
     {id: '7513764', format: 'png', size: 512, color: '#FFFFFF', background: '#1B6E8C', shape: 'circle'},
   ]))
   ```

   Request fields: `id`; `format` (`'svg'` default or `'png'`); `size` (PNG only: 100 to 3600 px, default 512; the site offers 100, 128, 512, 1200 and 3600); `color` (icon colour, default black); `background` (fill colour, or omit for transparent); `shape` (`'square'` or `'circle'`, used with `background`); `rotation` (0, 90, 180 or 270); `flipX`, `flipY`; and `name` (file stem, otherwise `<term>-<id>`). File names end with the colour, plus the size for PNGs.
4. The call returns the planned file names, then the tab moves to localhost and back. Check the receiver's output for saved paths and errors, then look at the files. View PNGs directly. For SVGs, render a preview with `magick in.svg -resize 256x256 preview.png`.

## Licence and records

The receiver appends one record per file to `noun-project-icons.json` in the output folder. Each record holds the icon ID and page, title, creator, settings, licence, a ready-made credit line and the download time. Keep this file with the icons so the source of each icon can be traced later.

- Attribution isn't required under Pro, but the `credit` line is there if Finn wants to credit creators.
- Use icons in deliverables (documents, decks, sites, apps). Don't publish them as a downloadable icon pack, commit them to a public repository as a reusable asset library, or use them in a logo or trademark, without checking Noun Project's licence terms first.
- Noun Studio editing and derivative rights belong to Creator Pro, which `creatorPro` shows this account doesn't have.

## Colour and design

- For Scarlatti outputs, take colours from the `scarlatti-designed-outputs` skill rather than guessing.
- The site's SVG renderer can round a channel by one (for example, `#1B6E8C` came back as `#1a6e8c`). If the exact value matters, change the `fill` attribute in the downloaded SVG.
- For documents and decks, SVG scales best. For Word, or when a tool can't take SVG, use a 512 or 1200 px PNG.

## When something breaks

- If `iconSearch` or `downloadIcon` returns a GraphQL error, the site has probably changed its schema. Set up a temporary wrapper around `window.fetch` that records `/graphql/` request bodies. Click the matching control on the site once: "Load Next" for search, or a download button for download. Then update the query in `noun_page.js`. Before clicking a download button, replace `HTMLAnchorElement.prototype.click` with a function that does nothing, so the Save As dialog doesn't open.
- If the form submission doesn't reach the receiver, check that it is still running and that the port matches. `curl.exe -X POST http://localhost:PORT/x/batch` from WSL tests whether Windows can reach it (expect a 403).
- Don't use `fetch()` to post to localhost from the page: Chrome blocks it behind a local-network permission prompt.
