# S-023 — Multi-select batch deletion of entries

**Type:** Feature + UX  
**Phase:** Phase 3 addition  
**Effort:** 1.5–2 days  
**Depends on:** S-013 (theme), S-018 (entry list + navigation)  
**Blocks:** Nothing in v1 critical path

---

## User story

> As a wrait user, I want to long-press an entry to enter selection mode, select multiple entries, and delete them in a single action — so I can quickly clear unwanted or accidental recordings without navigating into each one individually.

---

## Context and rationale

**V1 deferred edit/delete — now justified.** The original v1 scope deferred delete entirely ("read-only diary philosophy — reconsider with feedback"). Batch deletion is the right first unlock: it preserves the friction of deleting a single entry (no accidental taps) while respecting that testers will accumulate test recordings and failed drafts they need to clear.

**No inline swipe-to-delete.** Swipe gestures on the entry list are reserved — swipe-up on the main screen navigates to this list, and the entry detail has no swipe override. A dedicated long-press selection mode is safer and more discoverable for this audience.

---

## UX model and constraints

| Topic | Behaviour |
|---|---|
| **Entry into selection mode** | Long-press any entry card (450ms) — haptic feedback fires, pressed card becomes first selected item |
| **Selecting** | Tap any card to toggle selection on/off. Selected cards get an amber circular checkmark and warm-tinted background |
| **Exit without deleting** | System back or tapping ✕ Cancel exits selection mode and deselects everything |
| **Select all** | "Select all" link in the action bar selects all entries. Tapping again deselects all (does not exit selection mode) |

### Action bar (replaces top of screen in selection mode)

| Position | Element |
|---|---|
| Left | ✕ Cancel — exits selection mode with haptic feedback |
| Centre | `N selected` — live count, updates on each tap |
| Right | Select all / Deselect all — toggles whole list |

### Delete button (pinned at bottom)

| State | Behaviour |
|---|---|
| Default | `Delete N entries` in warm red — pinned above system navigation bar |
| Disabled | Button present but 40% opacity when N = 0 |
| Singular | `Delete 1 entry` (not "entries") for correct grammar |

---

## Deletion flow

1. User long-presses an entry card for **450ms**. Haptic feedback fires (`HapticFeedbackType.LongPress`). Card gains selection state. Action bar slides in from top (300ms fade + translate). Delete button fades in at bottom.
2. User taps additional entries to include them. Counter updates. Tapping a selected card deselects it.
3. User taps **"Delete N entries"**. A confirmation dialog appears: `"Delete N entries? This cannot be undone."` — two buttons: **Cancel** and **Delete** (red text).
4. On confirm: `EntryRepository.deleteEntries(ids)` called via `viewModelScope.launch`. The `LazyColumn` updates reactively — deleted cards animate out with a 200ms fade. Selection mode exits automatically.
5. Status line on main screen shows **"N entries deleted"** for 3s on next navigation back, using the existing status line mechanism from `MainUiState`.

> **No undo in v1.** The confirmation dialog is the safety net. Undo via a snackbar would require keeping deleted entries in memory and a temporary soft-delete — over-engineered for a beta where testers know each other. Re-evaluate if beta feedback requests it.

---

## Acceptance criteria

### Entry into selection mode

- Long-pressing any entry (clean or draft) for 450ms enters selection mode
- The long-pressed entry is automatically selected as the first item
- Haptic feedback fires on long-press activation (`LongPress` type)
- Normal tap-to-open behaviour is disabled while in selection mode
- The action bar appears with a slide-in animation (300ms)

### Selection behaviour

- Tapping an unselected card in selection mode selects it — amber ring + background tint applied
- Tapping a selected card deselects it — styling removed
- Action bar counter reflects the current count in real time
- "Select all" selects every entry currently in the list; tapping again deselects all (does not exit mode)
- Scrolling does not exit selection mode — selected state persists through scroll

### Confirmation and deletion

- Tapping "Delete N entries" shows a Material3 `AlertDialog` with correct singular/plural copy
- Tapping Cancel in the dialog dismisses it — selection is preserved, user can continue
- Tapping Delete in the dialog removes entries from the database and the list
- Deleted entries disappear with a 200ms fade from the `LazyColumn`
- If all entries are deleted, the list shows the empty state ("your entries will appear here")
- Selection mode exits automatically after confirmed deletion

### Cancellation and edge cases

- System back exits selection mode without deleting anything
- Pressing ✕ in the action bar exits selection mode without deleting anything
- If a pending draft is selected and deleted, it is removed from the draft retry queue
- If the app is backgrounded mid-selection, selection state is not persisted — mode resets on return
- Delete button is visually disabled (40% opacity) when no entries are selected

---

## Implementation tasks

- [ ] Add `selectionMode: Boolean` and `selectedIds: Set<Long>` to `EntryListUiState`
- [ ] Add `onLongPress` handler to each entry card composable using `combinedClickable` — `onClick` and `onLongClick`
- [ ] Trigger `LocalHapticFeedback.current.performHapticFeedback(HapticFeedbackType.LongPress)` on activation
- [ ] Build `SelectionActionBar` composable — cancel button, count text, select-all link. Animate in/out with `AnimatedVisibility` (fade + slide, 300ms)
- [ ] Build pinned `DeleteButton` composable at bottom of `EntryListScreen` — amber/red fill, disabled at opacity 0.4 when count = 0, uses correct singular/plural
- [ ] Add selected visual state to entry card: amber circular checkmark (`Canvas` circle + checkmark path), warm background tint via `animateColorAsState`
- [ ] Add `deleteEntries(ids: List<Long>)` to `EntryDao` — `@Query("DELETE FROM entries WHERE id IN (:ids)")`
- [ ] Add `deleteEntries(ids: List<Long>)` to `EntryRepository` interface and `EntryRepositoryImpl`
- [ ] Add `deleteEntries` to `EntryListViewModel` — call in `viewModelScope.launch { withContext(Dispatchers.IO) }`
- [ ] Show Material3 `AlertDialog` on delete tap — wire cancel/confirm actions to ViewModel
- [ ] Reset selection state in ViewModel after confirmed deletion
- [ ] Pass deletion count to `MainViewModel` so status line shows `"N entries deleted"` on next return to main screen

---

## Claude Code prompt

```
Add multi-select batch deletion to EntryListScreen. Selection mode is activated by
long-pressing an entry card (450ms, HapticFeedbackType.LongPress). While active: a
SelectionActionBar appears at top (animated, shows count + cancel + select-all), a
DeleteButton is pinned at the bottom. Selected cards show an amber circular checkmark
and tinted background via animateColorAsState. Tapping Delete shows an AlertDialog;
on confirm, calls EntryRepository.deleteEntries(ids). State: selectionMode: Boolean
and selectedIds: Set<Long> in EntryListUiState. Everything via StateFlow in
EntryListViewModel. Use the existing Entry domain model: [paste your Entry data class].
Use the existing WrAitTheme design tokens.
```