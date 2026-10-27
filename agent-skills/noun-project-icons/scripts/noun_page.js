// Run in a thenounproject.com tab signed in to the user's Icon Pro account.
// Defines window.nounIcons; the last line returns the account status.
// These are the same GraphQL calls the site's own search and download buttons make.
window.nounIcons = (() => {
  const SEARCH = `query iconSearch($query: String!, $filters: IconSearchFilter, $limit: Int, $offset: Int) {
    iconSearch(query: $query, filters: $filters, limit: $limit, offset: $offset) {
      items { id url title tags { slug } creator { name username } license }
      totalCount
    }
  }`;
  const DOWNLOAD = `mutation downloadIcon($iconId: ID!, $exportSize: Int, $imageFormat: IconFileType, $foregroundColor: String, $backgroundShapeColor: String, $backgroundShapeOpacity: Float, $backgroundShape: IconBackgroundShape, $rotation: Int, $flipX: Boolean, $flipY: Boolean, $clientApp: ClientAppType = WEB) {
    downloadIcon(iconId: $iconId, exportSize: $exportSize, imageFormat: $imageFormat, foregroundColor: $foregroundColor, backgroundShapeColor: $backgroundShapeColor, backgroundShapeOpacity: $backgroundShapeOpacity, backgroundShape: $backgroundShape, rotation: $rotation, flipX: $flipX, flipY: $flipY, clientApp: $clientApp) {
      ok errors base64Stream termSlug creatorDisplayName
    }
  }`;

  async function graphql(operationName, query, variables) {
    const response = await fetch('/graphql/', {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ operationName, query, variables }),
    });
    const body = await response.json();
    if (!response.ok || body.errors) {
      throw new Error(`${operationName} failed: HTTP ${response.status} ${JSON.stringify(body.errors || '')}`);
    }
    return body.data;
  }

  function account() {
    const user = window.__NEXT_DATA__?.props?.pageProps?.initialState?.user || {};
    return {
      signedIn: Boolean(user.username || user.id),
      iconPro: user.hasIconProSubscription === true,
      creatorPro: user.hasCreatorProSubscription === true,
    };
  }

  // style: 'line', 'solid' or both as an array. weight: line weight filter, as the site sends it.
  async function search(query, { style = null, weight = null, limit = 40, offset = 0 } = {}) {
    const filters = { style: style ? [].concat(style) : null, weight, aiAllowed: null };
    const data = await graphql('iconSearch', SEARCH, { query, filters, limit, offset });
    return {
      total: data.iconSearch.totalCount,
      offset,
      icons: data.iconSearch.items.map((item) => ({
        id: item.id,
        title: item.title,
        creator: item.creator?.name,
        tags: item.tags.slice(0, 8).map((tag) => tag.slug).join(' '),
      })),
    };
  }

  function slug(text) {
    return String(text || 'icon').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40) || 'icon';
  }

  // Each request: {id, format: 'svg'|'png', size: 100-3600 (PNG only), color: '#RRGGBB',
  // background: '#RRGGBB' or null, shape: 'square'|'circle', rotation: 0|90|180|270,
  // flipX, flipY, name: optional file stem}.
  // Fetches every file, then submits them in one form POST to the receiver, which saves
  // them and redirects this tab back here. Returns a summary before the tab navigates.
  async function send(receiver, requests) {
    const files = [];
    const records = [];
    for (const request of requests) {
      const format = (request.format || 'svg').toUpperCase();
      const color = (request.color || '#000000').toUpperCase();
      const size = format === 'PNG' ? request.size || 512 : 1200;
      const data = await graphql('downloadIcon', DOWNLOAD, {
        clientApp: 'WEB',
        iconId: String(request.id),
        imageFormat: format,
        exportSize: size,
        foregroundColor: color,
        backgroundShapeColor: request.background || '#000000',
        backgroundShapeOpacity: request.background ? 1 : 0,
        backgroundShape: (request.shape || 'square').toUpperCase(),
        rotation: request.rotation || 0,
        flipX: Boolean(request.flipX),
        flipY: Boolean(request.flipY),
      });
      const result = data.downloadIcon;
      if (!result.ok || !result.base64Stream) {
        records.push({ id: String(request.id), error: result.errors || 'no file returned' });
        continue;
      }
      const stem = request.name ? slug(request.name) : `${slug(result.termSlug)}-${request.id}`;
      const name = `${stem}-${color.slice(1).toLowerCase()}${format === 'PNG' ? `-${size}` : ''}.${format.toLowerCase()}`;
      files.push({ name, base64: result.base64Stream });
      records.push({
        id: String(request.id),
        file: name,
        title: result.termSlug,
        creator: result.creatorDisplayName,
        page: `https://thenounproject.com/icon/${request.id}/`,
        format: format.toLowerCase(),
        size: format === 'PNG' ? size : null,
        color,
        background: request.background || null,
        shape: request.background ? (request.shape || 'square') : null,
        rotation: request.rotation || 0,
        flipX: Boolean(request.flipX),
        flipY: Boolean(request.flipY),
        licence: account().iconPro ? 'Noun Project Icon Pro royalty-free licence' : 'unknown: account was not Icon Pro',
        credit: `${result.termSlug} by ${result.creatorDisplayName} from Noun Project`,
        downloaded: new Date().toISOString(),
      });
    }
    if (files.length) {
      const form = document.createElement('form');
      form.method = 'POST';
      form.action = receiver.replace(/\/?$/, '/') + 'batch';
      form.style.display = 'none';
      const input = document.createElement('input');
      input.type = 'hidden';
      input.name = 'payload';
      input.value = JSON.stringify({ files, records, return_to: location.href });
      form.appendChild(input);
      document.body.appendChild(form);
      setTimeout(() => form.submit(), 50);
    }
    return records.map(({ id, file, error }) => (error ? { id, error } : { id, file }));
  }

  return { account, search, send };
})();
window.nounIcons.account();
