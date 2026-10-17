# Feature Specification: Tags and categories

> **Feature number:** 053
> **Status:** Draft
> **Author:** Claude
> **Date:** 2026-10-14
> **Work item:** Not assigned

## Status history

| Date       | Status | Author | Notes                          |
| ---------- | ------ | ------ | ------------------------------ |
| 2026-10-14 | Draft  | Claude | Initial spec from research findings |
| 2026-10-16 | Draft  | Claude | Clarify phase: resolved open questions, added limits and constraints |

---

## Overview

Users currently browse entries only by date. As the journal grows, finding
entries by topic or theme becomes difficult even with text search. Tags let
users organize entries into user-defined categories (e.g., "work," "health,"
"travel," "gratitude") and filter the entry list to a single tag.

Research shows users strongly prefer flexible tag-based systems over rigid
folders. Apple Journal's lack of tagging is consistently cited as its biggest
weakness. The ideal system combines user-created tags with low-friction
application — tagging should feel optional, never burdensome.

## User stories

- As a journal user, I want to assign one or more tags to an entry so that I
  can organize entries by topic.
- As a journal user, I want to filter my entry list by a tag so that I can
  see only entries related to a specific theme.
- As a journal user, I want to create new tags on the fly while tagging an
  entry so that I do not need to pre-configure categories.
- As a journal user, I want to remove a tag from an entry so that I can
  correct mistakes.
- As a journal user, I want to see which tags exist and how many entries each
  has so that I can browse my journal by topic.
- As a journal user, I want tagging to be optional so that entries without
  tags remain fully functional.

## Acceptance criteria

### Tag management

- [ ] The user can create a new tag by typing a name. Tag names are
      case-insensitive, trimmed, and limited to 15 characters.
- [ ] Duplicate tag names (case-insensitive) are not allowed.
- [ ] The user can delete a tag. Deleting a tag removes it from all entries
      but does not delete the entries themselves. A confirmation is required.
- [ ] Tags have no hierarchy — the system is a flat list.
- [ ] The system enforces a maximum of 10 tags total. When the limit is
      reached, the UI prevents creating new tags and shows a clear message
      explaining the limit.
- [ ] Tag management is done through a dedicated "Manage Tags" screen,
      accessible from the entry list. The screen shows all tags with entry
      counts and allows adding and deleting tags. Renaming is out of scope.

### Assigning tags to entries

- [ ] On the entry detail screen, the user can add or remove tags from that
      entry.
- [ ] Assigning tags shows the list of existing tags with a way to select or
      deselect, plus an inline field to create a new tag.
- [ ] An entry can have zero or more tags. There is no enforced per-entry
      maximum, but the UI should remain usable with many tags on one entry.
- [ ] Tags are visible on the entry detail screen and as compact labels on
      entry list cards.
- [ ] Draft entries can be tagged.

### Filtering

- [ ] The entry list screen provides a horizontal scrollable chip row below
      the search bar to filter by one tag at a time.
- [ ] When a tag filter is active, only entries with that tag are shown.
- [ ] The tag filter composes with the existing text search: both can be
      active simultaneously (AND logic).
- [ ] Clearing the tag filter restores the full list (or the text-search-
      filtered list if a search query is active).
- [ ] The tag filter persists during navigation within the session (e.g.,
      navigating to entry detail and back preserves the filter). Filter
      persistence across app restarts is out of scope.
- [ ] When a tag filter is active but no entries match, a "No entries with
      this tag" message is shown with a "Clear filter" action.
- [ ] Export and import operate on the complete entry collection regardless
      of active filters (consistent with existing search behavior per spec
      046).

### Search integration

- [ ] Tag names are included in the text search scope: searching for a tag
      name matches entries that carry that tag, even if the tag name does not
      appear in the entry text.

### CSV export and import

- [ ] Tags are included in the CSV export as a new `tags` column appended
      after the existing columns. Multiple tag names are separated by
      semicolons within the cell (e.g., `work;health`).
- [ ] Importing a CSV with a `tags` column auto-creates any tags that do not
      already exist, subject to the 10-tag system limit. Tags beyond the limit
      are silently skipped.
- [ ] Importing a CSV without a `tags` column works as before (no tags
      assigned).

## API contract

This feature introduces no HTTP endpoints and does not change the backend API.
Tags are stored and managed entirely on-device.

## Data model changes

New local data:

- A `Tag` entity with: `id` (auto-increment), `name` (text, unique
  case-insensitive).
- A join table (`EntryTags`) associating entry IDs to tag IDs (many-to-many),
  with `ON DELETE CASCADE` on both foreign keys so that deleting an entry or
  a tag atomically removes the associations.

The existing `Entry` model gains an in-memory `tags` association loaded from
the join table. The persisted entry table itself is not altered.

Migration: additive — creates new table(s) only. No existing data is modified.

## Dependencies

- [ ] Existing entry repository and local database.
- [ ] Existing entry list screen and entry detail screen.
- [ ] Existing text search (spec 046) for composable filtering.
- [ ] Existing CSV export/import services for the new `tags` column.

## UX / design references

No external design reference required. Tag chips should follow the existing
app color tokens and typography. Tag selection UI should be a bottom sheet
consistent with the current design language. Tags are displayed in
alphabetical order everywhere (chip row, picker, manage screen).

## Non-functional requirements

- **Performance:** Tag filtering should be immediate for the expected entry
  volume. Loading tags for an entry or filtering the list should not introduce
  noticeable latency.
- **Security:** Tag names and associations are stored in the existing encrypted
  database. Tag data never leaves the device.
- **Reliability:** Deleting an entry removes its tag associations. Deleting a
  tag removes only the association, never the entry. These operations must be
  atomic (enforced via `ON DELETE CASCADE`).
- **Observability:** Track analytics events for: tag created, tag assigned,
  tag filter activated. Do not log tag names. _(Deferred: no analytics
  infrastructure exists in the app yet. Will be implemented when an analytics
  service is added.)_

## Out of scope

- Tag colors or icons.
- Hierarchical tags or nested categories.
- Auto-tagging via AI or keyword extraction.
- Tag-based statistics or analytics dashboards.
- Bulk-tagging multiple entries at once.
- Tag suggestions based on entry content.
- Pinned or favorite tags.
- Tag ordering or custom sort.
- Tag renaming.
- Filter persistence across app restarts.
- Any character restrictions on tag names beyond the 15-character length limit.

## Open questions

All open questions have been resolved during the Clarify phase.
