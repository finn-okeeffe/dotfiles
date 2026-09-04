# Cover-Art Preparation and Upload

Consult current MusicBrainz guidance before preparing or uploading:

- [How to add cover art](https://musicbrainz.org/doc/How_to_Add_Cover_Art)
- [Cover-art types](https://musicbrainz.org/doc/Cover_Art/Types)
- [How to scan cover art](https://musicbrainz.org/doc/How_to_Scan_Cover_Art)
- [Release cover-art style](https://musicbrainz.org/doc/Style/Release#Cover_art)

## Edition Safety

Cover art must belong to the exact release edition. Verify against barcode, catalogue number, format, packaging, country/date, tracklist, logos, legal text, matrix/pressing evidence, and the shape/design of the physical item.

Prefer, in order:

1. User-supplied scans or photographs of the exact copy.
2. Original artwork delivered with the exact digital release.
3. High-resolution artist or label images tied to the exact edition.
4. Other public images only when multiple identifiers or distinctive details establish the edition.

Do not use an image merely because it represents the same album. Do not substitute square digital art for physical packaging unless its shape and design exactly match. Avoid watermarks where possible; if the only acceptable exact-edition image is watermarked, mark it with the current MusicBrainz Watermark type.

Record the source URL or supplied filename, access date where applicable, provenance, and exact-edition evidence. Do not bypass access controls or download restrictions.

## Non-Destructive Preparation

- Preserve every original and work on copies.
- Prefer lossless output for scans. Keep the largest useful resolution; MusicBrainz recommends 600 dpi for new scans.
- Rotation, cropping empty scanner margins, joining panels that belong in one view, and extracting PDF pages are acceptable when they preserve the released artwork.
- Do not remove stickers, repair damage, redraw text, replace backgrounds, alter layout, recolour creatively, generate missing regions, or upscale with AI.
- If an image remains an uncropped or otherwise rough reference, use the current Raw/Unedited type rather than disguising its condition.
- Do not recompress lossy source files unnecessarily.

Use clear ordered names such as `01-front.png`, `02-back-spine.png`, `03-medium-1.png`, and `04-booklet-01.png`. Assign every applicable current MusicBrainz type, a short factual comment only when useful, and a stable order. Front and Back images intended as primary should appear first among images of that type.

## Submission Boundary

Cover art can be uploaded only after the release exists. Before upload:

1. Confirm the new release MBID and compare its edition fields against the manifest.
2. Present the ordered manifest, provenance, types, comments, and edit note to the user.
3. Obtain explicit approval for the cover-art batch separately from release creation.
4. Use the authenticated MusicBrainz Cover Art tab when browser interaction is available; otherwise provide the direct release URL and exact upload order.

After submission, report the release URL and whether the artwork is pending or approved. On an upload error or edition mismatch, stop rather than retrying automatically.
