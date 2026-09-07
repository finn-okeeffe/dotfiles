# Research and Duplicate-Decision Workflow

Use current MusicBrainz documentation as the authority:

- [MusicBrainz Web Service](https://musicbrainz.org/doc/MusicBrainz_API)
- [Search syntax](https://musicbrainz.org/doc/MusicBrainz_API/Search)
- [Release style](https://musicbrainz.org/doc/Style/Release)
- [How to add a release](https://musicbrainz.org/doc/How_to_Add_a_Release)
- [Release editor seeding](https://musicbrainz.org/doc/Development/Seeding/Release_Editor)
- [Writing edit notes](https://musicbrainz.org/doc/How_to_Write_Edit_Notes)

Check current documentation when a field, status, format, relationship, or style choice is uncertain; do not rely on this reference as a frozen copy of MusicBrainz rules.

## Evidence Priority

Prefer, in order:

1. The exact physical item, original digital files, booklet, liner notes, matrix/runout, or download supplied by the user.
2. Artist, label, publisher, distributor, or store pages that identify the exact edition.
3. Discogs or another structured catalogue whose identifiers and images match the edition.
4. Retail, marketplace, library, archive, or review pages with edition-specific evidence.
5. Search snippets or unattributed aggregations only as leads, never as sole support for a material field.

Record direct URLs, access dates, supplied filenames/page numbers, conflicts, and uncertainty. A source supports only what it actually shows.

## Duplicate Search

Search in widening passes:

1. Exact barcode, including a checksum-aware comparison when practical.
2. Catalogue number with label; also search normalized spacing and punctuation variants.
3. Credited artist and release title, including printed and transliterated variants.
4. Release-group candidates, then their releases.
5. Track sequence, track lengths, medium count and format.
6. Country/date, packaging, artwork, legal text, matrix/runout, mastering and pressing details.

An exact release must be the same edition, not merely the same album or release group. For physical media, meaningful artwork or legal-text differences normally indicate a separate release. Different formats and physical-versus-digital editions are separate. For digital editions, apply MusicBrainz's current rules rather than treating different storefronts as automatically separate.

When a candidate is incomplete, compare the known fields rather than assuming that blanks match. If two candidates remain plausible, classify the result as ambiguous and ask targeted questions.

## Drafting Decisions

- Transcribe titles and artist credits according to current MusicBrainz style and artist intent; preserve credited-as text and join phrases.
- Match existing artists, labels, recordings and works by identity, not name alone.
- Use the release date for this edition, not an original album date, recording date, copyright date, or import date.
- Use imprints as labels; do not turn distributors, retailers, copyright holders, or pressing plants into labels without evidence.
- Record `none` only when the release affirmatively has no barcode or catalogue number; otherwise leave unknown values blank.
- Reuse recordings only when the audio identity is supported. It is safer to create a new recording than to attach a demonstrably different mix, edit, performance, or mastering as the same recording.
- Add relationships and credits only when their direction, target, role, attributes, and credited wording are supported.
- In the edit note, identify the physical item or original digital release, summarize external corroboration, and explain any non-obvious choices. Do not paste irrelevant research logs.

## Questioning the User

Inspect and research first. Then group only unresolved questions that affect:

- exact-edition identity;
- release-group placement or primary/secondary type;
- artist/label/entity identity;
- tracklist, medium format, packaging, barcode or catalogue number;
- date/country, language/script, status;
- whether two credited names refer to the same entity;
- whether artwork belongs to the exact edition.

If the user does not know, leave the field unresolved or blank. Do not block a valid release seed on optional metadata.
