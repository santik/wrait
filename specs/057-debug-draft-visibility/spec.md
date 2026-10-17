# Feature Specification: Debug Draft Text Visibility

> **Feature number:** 057
> **Status:** Draft
> **Author:** alexander
> **Date:** 2026-10-16

## Status history

| Date       | Status | Author    | Notes                          |
| ---------- | ------ | --------- | ------------------------------ |
| 2026-10-16 | Draft  | alexander | Initial spec created           |
| 2026-10-17 | Draft  | alexander | Corrected scope: detail screen |

---

## Overview

Finalized entries display only their cleaned text on the entry detail screen. The raw transcript (the draft text before cleanup) is stored in the database but not visible to the user once cleanup completes. For debugging the cleanup pipeline, the developer needs to see the raw transcript alongside the cleaned text on finalized entries — but only on a specific device, not for regular users.

This feature adds a debug-only display of the raw transcript on the entry detail screen, gated by a compile-time device identifier that is compared against the app's persisted device ID at runtime.

## User stories

- As the developer, I want to see the raw transcript on finalized entries so that I can compare it with the cleaned text and debug the cleanup pipeline.
- As a regular user, I should only see the cleaned (or fallback raw) text as I do today, with no change to the entry detail screen.

## Acceptance criteria

- [ ] The entry list is unchanged — no entries are added or removed.
- [ ] On the entry detail screen, when the app's persisted device identifier matches a compile-time debug device identifier, the raw transcript is displayed in addition to the normal display text for finalized entries that have both a raw transcript and a cleaned text.
- [ ] The raw transcript section is visually distinct from the main entry text (e.g. different styling or a labeled section) so it is clearly debug information.
- [ ] When the identifiers do not match or the compile-time value is empty/absent, the entry detail screen behaves exactly as it does today.
- [ ] The comparison uses the same resolved device identifier that the app persists and sends to the backend (`PreferencesRepository.getDeviceId()`).
- [ ] The debug device identifier is not exposed in the app UI. It may appear in build logs (e.g. CI) since the device ID is already transmitted to the backend and is not itself a secret.
- [ ] Entries that have no cleaned text (draft or raw-only entries) show no additional debug section — there is nothing extra to compare.

## API contract

No API changes.

## Data model changes

No data model changes. The raw transcript is already stored on every entry.

## Dependencies

- Existing device identifier from `PreferencesRepository.getDeviceId()`.
- Existing compile-time define mechanism (`--dart-define` / `String.fromEnvironment`).

## Non-functional requirements

- **Security:** The debug device identifier must not appear in logs, analytics, or transmitted data.
- **Performance:** Reading the already-cached device ID and comparing a string adds negligible overhead.

## Out of scope

- Changing the entry list (filtering, reordering, or adding draft entries).
- UI toggle or settings screen option for debug visibility.
- Backend-driven debug device list.
- Changing how drafts are created, retried, or cleaned up.

## Open questions

None.
