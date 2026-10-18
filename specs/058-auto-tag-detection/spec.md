# Feature Specification: Auto-tag detection

> **Feature number:** 058
> **Status:** Draft
> **Author:** Claude
> **Date:** 2026-10-18
> **Work item:** Not assigned

## Status history

| Date       | Status | Author | Notes                |
| ---------- | ------ | ------ | -------------------- |
| 2026-10-18 | Draft  | Claude | Initial spec created |
| 2026-10-18 | Draft  | Claude | Clarify phase: no ambiguities found, spec is self-contained |

---

## Overview

When a user records a diary entry, the app currently transcribes and cleans up
the text but does not suggest any tags. Users must manually navigate to the
entry detail screen and assign tags after the fact. This creates friction that
reduces tag adoption.

Auto-tag detection sends the raw transcript and the user's existing tags to a
new backend endpoint (`POST /api/tag`) that classifies the text against the
supplied tags. The call runs in parallel with the existing cleanup call so it
adds no visible latency to the recording flow. Tags with a probability above
50% are automatically assigned to the newly created entry.

The feature is opportunistic: if the user has no tags, or the transcript is
empty, or the tag call fails, the entry is saved normally without auto-tags.
Auto-tagging never blocks or delays entry creation.

## User stories

- As a journal user, I want my entries to be automatically tagged based on
  their content so that I do not have to manually assign tags every time.
- As a journal user, I want auto-tagging to use my own tags so that the
  results are relevant to my personal categories.
- As a journal user, I want auto-tagging to be silent and non-blocking so that
  my recording flow is not slowed down or interrupted by tag failures.

## Acceptance criteria

### When auto-tagging runs

- [ ] Auto-tag detection runs in parallel with the cleanup API call, using the
      same raw transcript that cleanup receives.
- [ ] Auto-tag detection is skipped (no API call) when the user has fewer than
      2 tags (the `/api/tag` endpoint requires at least 2).
- [ ] Auto-tag detection is skipped (no API call) when the raw transcript is
      empty or blank.

### Tag assignment

- [ ] Tags whose probability in the response is strictly greater than 0.5 are
      automatically assigned to the entry.
- [ ] Tags are assigned after the entry has been persisted (cleanup success
      determines the entry ID).
- [ ] If cleanup fails (entry stays as draft), no auto-tags are assigned.
- [ ] If the auto-tag API call fails (network error, timeout, 4xx/5xx), the
      entry is saved normally without auto-tags. No error is surfaced to the
      user.
- [ ] If the auto-tag API call succeeds but no tag exceeds the 50% threshold,
      no tags are assigned.
- [ ] Auto-detected tags are merged (union) with any tags already assigned to
      the entry. Existing manual assignments are never removed.

### Retry path

- [ ] When pending drafts are retried on app launch, auto-tag detection also
      runs alongside the retry cleanup call, following the same rules.

### API contract

- [ ] The app sends the raw transcript (not the cleaned text) to the tag
      endpoint, trimmed and bounded to 10,000 characters (matching the
      endpoint's `maxLength`).
- [ ] The app sends the user's tag names as the `tags` array.

## API contract

### `POST /api/tag`

**Request:**

```json
{
  "text": "string (1–10,000 chars) — the raw transcript to classify",
  "tags": ["string", "..."] — 2–50 unique non-empty tag names
}
```

**Response (success — 200):**

```json
{
  "tags": [
    { "tag": "work", "probability": 0.82 },
    { "tag": "health", "probability": 0.15 }
  ]
}
```

**Error responses:**

| Status | Body                 | When                                    |
| ------ | -------------------- | --------------------------------------- |
| 400    | `{ "error": "..." }` | Invalid input (empty text, <2 tags)     |
| 401    | `{ "error": "..." }` | Missing or invalid proxy secret         |
| 413    | `{ "error": "..." }` | Request too large                       |
| 429    | `{ "error": "..." }` | Daily record limit exceeded             |
| 500    | `{ "error": "..." }` | Internal backend error                  |
| 502    | `{ "error": "..." }` | Upstream service error                  |
| 504    | `{ "error": "..." }` | Upstream timeout                        |

## Data model changes

None. Tags and entry-tag associations already exist (spec 053). This feature
uses the existing `TagRepository.setTagsForEntry()` method to assign
auto-detected tags. No new tables or columns are needed.

## Dependencies

- [ ] Tags and categories feature (spec 053) — tag data model and repository.
- [ ] Backend `/api/tag` endpoint — defined in `api/openapi.yaml`.
- [ ] Existing cleanup transcript flow — auto-tag runs in parallel with it.

## UX / design references

No UI changes. Auto-tagging is invisible to the user — tags simply appear on
the entry after recording. The user can still add or remove tags manually on
the entry detail screen as before.

## Non-functional requirements

- **Performance:** The auto-tag API call must not add latency to the entry
  creation flow. It runs concurrently with cleanup and its result is applied
  asynchronously after the entry is persisted.
- **Security:** The tag endpoint uses the same `X-Proxy-Secret` and
  `X-Device-Id` headers as all other backend calls. Tag names transit to the
  backend but the backend is stateless (does not persist them).
- **Reliability:** Auto-tag failure is fully silent. The entry is always saved
  regardless of whether auto-tagging succeeds, fails, or times out.
- **Observability:** Auto-tag failures are logged locally at warning level
  (same pattern as cleanup failures). No user-facing error is shown.

## Out of scope

- UI to show suggested tags before assignment (auto-apply only).
- Confidence indicators or probability display to the user.
- User setting to enable/disable auto-tagging.
- Auto-tagging when the user manually edits an entry's text.
- Auto-tagging based on cleaned text (uses raw transcript only).
- Creating new tags based on API suggestions (only existing user tags are
  considered).

## Open questions

All open questions have been resolved during spec review.
