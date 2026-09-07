---
name: musicbrainz-release-assistant
description: Research whether an exact MusicBrainz release already exists and, when it does not, prepare an evidence-backed release submission pack and exact-edition cover art for user review. Use for physical or digital albums, EPs, singles, compilations, box sets, or other releases supplied as scans, photographs, booklets, metadata, or source links. Stop after reporting an exact existing release unless the user explicitly asks for a different task.
---

# MusicBrainz Release Assistant

Determine whether the user's exact edition already exists. If it does not, prepare a reviewable MusicBrainz submission without guessing or making public edits prematurely.

## Research Before Asking

Inspect every supplied scan, photograph, PDF, digital booklet, audio-file metadata export, and source link. For scanned PDFs, render pages for visual inspection when necessary. Treat the physical or digital release itself as the strongest source for what it actually says.

Search MusicBrainz before drafting. Use `scripts/musicbrainz_api.py` for read-only WS/2 searches and lookups when `MUSICBRAINZ_CONTACT` is set; otherwise use current public web research. Query barcode first when available, then catalogue number plus label, artist and title, tracklist, release group, format, country/date, packaging, artwork, legal text, and pressing identifiers. Respect current MusicBrainz guidance and the evidence hierarchy in [references/workflow.md](references/workflow.md).

Classify the result:

- **Exact release:** Return the MusicBrainz link and the evidence establishing the match, then stop. Do not create a work pack or propose improvements unless the user explicitly changes the task.
- **Different edition in an existing release group:** Reuse that release group and continue with a new release draft.
- **Ambiguous:** Explain the competing candidates and ask only the questions needed to distinguish them. Do not generate a seed yet.
- **No exact release:** Continue with the work pack.

Artwork differences, including legal text, generally distinguish physical releases. Do not treat a digital release as the same release as a physical edition. When uncertain, do not declare a duplicate.

## Prepare the Submission Pack

Read [references/work-pack.md](references/work-pack.md) before creating artifacts. Create a new, non-destructive directory under `musicbrainz-work/<artist>--<title>--<edition>/`; never overwrite source files or an existing pack.

Populate all evidenced data, including release and release-group fields, media and tracklists, existing entity matches, recordings, works, performers, production credits, identifiers, URLs, and relationships. Match existing artists, labels, recordings, and works before proposing new entities. Record the source for each material decision.

After research, ask grouped questions only for unresolved facts that materially affect identity or submission. Accept "unknown" and leave unsupported fields blank. Never convert a copyright date into a release date, infer a label from a copyright company, or invent a relationship.

Generate `release-seed.html` with `scripts/build_release_seed.py`. Put relationships and credits that the release seeder cannot represent in `follow-up-edits.md`. Run `scripts/validate_release_pack.py` before presenting the pack.

## Prepare Cover Art

Read [references/cover-art.md](references/cover-art.md) whenever images are present or discoverable. Prefer user scans or original digital artwork. Public images are acceptable only when evidence ties them confidently to the exact edition and their provenance is recorded.

Preserve originals. Work only on copies, and limit preparation to non-generative operations such as lossless rotation, cropping, or page extraction. Never use generative fill, AI reconstruction, AI upscaling, or invented artwork. Reject uncertain-edition art.

Prepare ordered files and `cover-art-manifest.json`, but do not upload until a release MBID exists.

## Review and External Actions

Present the duplicate conclusion or the complete work pack first. Clearly list unresolved fields, proposed new entities, existing MBIDs, artwork provenance, and post-creation follow-up edits.

Public MusicBrainz edits require the user's review and explicit approval. After approval, use an authenticated browser session when available; never request, store, or handle the user's MusicBrainz password. If browser automation is unavailable, hand off the seeded editor file and exact next steps.

Treat release submission and cover-art upload as separate approval checkpoints. After release creation, confirm the returned release MBID and exact edition before uploading the ordered artwork batch. Stop after a failed or uncertain submission and ask the user to inspect the rendered MusicBrainz form; do not retry public edits blindly.
