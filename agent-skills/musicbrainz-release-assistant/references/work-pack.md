# Work Pack

Create packs only after concluding that no exact MusicBrainz release exists. Use:

`<cwd>/musicbrainz-work/<artist-slug>--<title-slug>--<edition-slug>/`

Use lowercase filesystem-safe slugs. If the target exists, reuse it only when it is clearly the same in-progress release; otherwise create a dated sibling. Never overwrite a completed pack or any supplied source file.

## Required Layout

```text
release-draft.json
evidence.md
review.md
release-seed.html
follow-up-edits.md
cover-art/
cover-art-manifest.json
```

`evidence.md` records the duplicate searches, candidates considered, edition decision, source list, conflicts, and reasoning for non-obvious fields.

`review.md` gives the user a compact preview: exact edition, release-group decision, release fields, media/tracklist, matched and proposed entities, relationships, artwork, unresolved items, and submission sequence.

`follow-up-edits.md` contains only evidenced data that cannot be represented reliably by the release seeder, grouped into actions to perform after the release exists. An empty file should state that no follow-up edits are currently identified.

## `release-draft.json`

Use UTF-8 JSON with this top-level shape:

```json
{
  "schema_version": 1,
  "identity": {
    "exact_match_status": "no_exact_release",
    "release_group_mbid": null,
    "release_group_types": ["Album"]
  },
  "release": {
    "name": "Release title",
    "comment": null,
    "annotation": null,
    "barcode": null,
    "language": "eng",
    "script": "Latn",
    "status": "official",
    "packaging": "Digipak",
    "artist_credit": [],
    "events": [],
    "labels": [],
    "urls": []
  },
  "media": [],
  "relationships": [],
  "sources": [],
  "unresolved": [],
  "edit_note": ""
}
```

Artist credits contain `name`, optional `artist_name`, optional `mbid`, and optional `join_phrase`. Events contain an ISO-style partial `date` (`YYYY`, `YYYY-MM`, or `YYYY-MM-DD`) and optional ISO country code. Labels contain optional `name`, `mbid`, and `catalog_number`. URLs contain `url` and optional integer `link_type`.

Each medium contains optional `title`, required `format`, and a non-empty `tracks` array. Each track contains `number`, `title`, optional `length` (`MM:SS` or milliseconds), optional `recording_mbid`, and optional `artist_credit` using the release-credit shape.

Relationships not handled by the release seeder use a generic evidence-bearing shape: `source_kind`, `source_ref`, `type`, `target_kind`, `target_name`, optional `target_mbid`, optional `attributes`, and `evidence_refs`.

Sources have a stable `id`, `kind` (`file`, `url`, or `user_statement`), `location`, optional `page`, `description`, and optional `accessed_at`. Material assertions should refer to source IDs in `evidence.md` or the relevant structured entry.

Unresolved entries contain `field`, `question`, `reason`, and `severity` (`required` or `optional`). A required unresolved item prevents seed generation; an optional one is disclosed but may remain blank.

## Cover-Art Manifest

Use:

```json
{
  "schema_version": 1,
  "images": [
    {
      "file": "01-front.png",
      "sha256": "lowercase hex digest",
      "order": 1,
      "types": ["Front"],
      "comment": "",
      "source": {
        "location": "scan-front.tif",
        "provenance": "User-supplied scan of this copy",
        "exact_edition_evidence": "Barcode and packaging match the draft"
      }
    }
  ],
  "edit_note": ""
}
```

Paths are relative to `cover-art/`. Orders must be positive and unique. Compute SHA-256 after all permitted preparation is complete.

## Building and Validation

From the skill directory:

```bash
python3 scripts/build_release_seed.py /path/to/release-draft.json --output /path/to/release-seed.html
python3 scripts/validate_release_pack.py /path/to/work-pack
```

The seed builder represents only fields documented by MusicBrainz's release seeder. Keep everything else in the draft and follow-up file for reviewed post-creation edits.
