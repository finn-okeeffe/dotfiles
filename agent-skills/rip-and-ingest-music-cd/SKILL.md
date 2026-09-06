---
name: rip-and-ingest-music-cd
description: Rip and ingest a music CD or multi-CD album. Use whenever the user asks to rip a CD.
---

# Rip and ingest music cd

This skill is used to rip and ingest a CD or multi-CD album. The key outcome is that the full album should be imported into /media/Oreki/srv/music/library/, with proper metadata and album art for Jellyfin to use. If importing a multi-CD album, it should be contained within a single album folder.

## Process

1. Using `whipper`, rip the CD into /media/Oreki/srv/music/incoming. If the CD cannot be ripped after 2 attempts, stop here and let the user know that ripping failed, and why.

2. If possible, identify the release. If this is not possible, stop here and prompt the user for scans of the physical media or more information, so that an appropriate music brainz release can be created using the musicbrainz-release-assistant skill.

3. If the release is multi-CD, repeatedly prompt the user for the next disc then use `whipper` to rip the CD until all discs have been read.

4. Prepare for ingestion. Most single-CD releases can skip this step. Multi-CD releases may require some additional preparation so that `beets` recognises the release correctly. If album art is not present in any release metadata source, ask the user for a scan or image of the album art.

5. Using `beet import ...`, import the disc into the main library with correct metadata. This will ingest the album into the library folder and ammend any malformed metadata. Prefer an accurate MusicBrainz release - but if one does not exist you may use other sources. A corresponding MusicBrainz release not existing should not be a blocker. You may with to pass additional flags to beets to help it use correct metadata. If `beets` cannot correctly identify the release and that cannot be resolved by passing additional flags or otherwise setting metadata, use the ask question tool to get any more required information, then return to step 4.

6. If all else fails but you can identify the release accurately, resort to a manual import by copying files and creating directories. Make sure that metadata is correctly formed and accurate, and that you match the structure of the rest of the library folder.

7. Review the final imported folder to make sure that it was correctly ripped and imported, the structure is in line with the rest of the library folder, and that album art is present. If any of this review fails, attempt to resolve it. If you cannot confidently resolve it or there is ambiguity, ask the user what to do next.

8. Clean up all log files and temporary metadata, apart from that which would be useful for step 9 if we need to create a MusicBrainz release. /media/Oreki/srv/music/incoming should now be mostly clean of all files created by `whipper`.

9. If a MusicBrainz release did not exist, prompt the user to run the musicbrainz-release-assistant skill to create the release.

## Sandboxing

 Note that /media/Oreki may appear read-only and some commands may fail due to sandboxing. If this is the case, try getting your commands approved to run outside the sandbox.
