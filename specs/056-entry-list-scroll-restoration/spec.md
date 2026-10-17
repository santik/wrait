# Feature Specification: Entry List Scroll Position Restoration

> **Feature number:** 056
> **Status:** Approved
> **Author:** Claude
> **Date:** 2026-10-16
> **Work item:** #056

## Status history

| Date       | Status | Author | Notes                |
| ---------- | ------ | ------ | -------------------- |
| 2026-10-16 | Draft    | Claude | Initial spec created |
| 2026-10-16 | Approved | Claude | Clarify: no gaps found |

---

## Overview

When a user scrolls down through the entry list, taps an entry to view its
details, and then navigates back, the list resets to the top. The user loses
their scroll position and must scroll again to find where they were.

The list should restore to the same scroll position the user was at before
they tapped the entry.

## User stories

- As a user, I want the entry list to remember my scroll position when I
  navigate back from an entry detail so that I can continue browsing where I
  left off.

## Acceptance criteria

- [ ] After tapping an entry, viewing it, and navigating back, the entry list
      is scrolled to the same position it was at before the tap.
- [ ] Scroll position is preserved regardless of how the user navigates back
      (back button, system back gesture).
- [ ] If entries are deleted while viewing a detail, the list adjusts
      gracefully (no crash or blank space at the bottom).
- [ ] Search state is independent of scroll restoration — filtering and
      clearing search may reset scroll position as expected.

## API contract

_No API changes required._

## Data model changes

_No data model changes required._

## Dependencies

- None. This is a UI-only change within the existing navigation stack.

## UX / design references

_Standard platform behavior — lists should preserve scroll position when
returning from a pushed detail screen._

## Non-functional requirements

- **Performance:** No additional memory or computation overhead beyond a
  scroll controller reference.
- **Security:** No impact.
- **Reliability:** Scroll restoration must not crash if the list content
  changes between navigation events.

## Out of scope

- Persisting scroll position across app restarts.
- Scroll position memory for the search-filtered list separately.
- Any changes to the entry detail screen layout or behavior.

## Open questions

_None._
