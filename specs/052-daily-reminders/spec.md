# Feature Specification: Daily reminders

> **Feature number:** 052
> **Status:** Draft
> **Author:** Alexander
> **Date:** 2026-10-14
> **Work item:** Not assigned

## Status history

| Date       | Status | Author    | Notes              |
| ---------- | ------ | --------- | ------------------ |
| 2026-10-14 | Draft  | Alexander | Initial spec draft |

---

## Overview

Users forget to journal. Two fixed daily reminders nudge them at the right
moments:

- **Morning reminder** — fires if the user has not created any entry today.
  Encourages starting the day with a reflection.
- **Evening reminder** — fires if the user still has remaining recording quota
  for the day. Encourages using up quota before it resets.

Both reminders are conditional: they are suppressed when the condition is not
met, so users are never nagged unnecessarily.

## User stories

- As a journal user, I want a morning reminder that only fires when I haven't
  journaled today so that I'm nudged to start but not bothered if I already
  did.
- As a journal user, I want an evening reminder that only fires when I still
  have quota left so that I'm reminded to use my remaining recordings before
  the day resets.
- As a journal user, I want a single toggle to turn both reminders on or off
  so that I can enable the feature without extra configuration.
- As a journal user, I want tapping a reminder notification to open the app
  ready to record so that I can start immediately.

## Acceptance criteria

### Settings UI

- [ ] A "Reminders" section appears in the settings screen.
- [ ] The section shows a single toggle to enable or disable both reminders
      together.
- [ ] Reminders default to enabled for new users.
- [ ] The reminder times are fixed (morning at 09:00, evening at 20:00) and
      not user-configurable.

### Morning reminder behavior

- [ ] When enabled, the morning reminder is scheduled daily at the configured
      time.
- [ ] At fire time, the app checks whether any entry (including drafts) was
      created today (local calendar day).
- [ ] If an entry exists for today, the notification is silently suppressed.
- [ ] If no entry exists for today, a local notification is shown.
- [ ] The notification text is a brief, non-revealing message (e.g., "Start
      your day with a reflection").

### Evening reminder behavior

- [ ] When enabled, the evening reminder is scheduled daily at the configured
      time.
- [ ] At fire time, the app checks whether the user has remaining recording
      quota for the current day.
- [ ] If remaining quota is 0, the notification is silently suppressed.
- [ ] If remaining quota is > 0, a local notification is shown.
- [ ] The notification text is a brief, non-revealing message (e.g., "You
      still have recordings left today").

### Notification behavior

- [ ] Notification text does not contain any entry content or personal data.
- [ ] Tapping the notification opens the app to the main (recording) screen.
- [ ] Reminders repeat daily at the configured times until disabled.
- [ ] Reminders persist across app restarts and device reboots.
- [ ] Reminders work without network connectivity for the notification itself.
      The condition check uses locally cached data.

### Permission handling

- [ ] On Android, the app requests the POST_NOTIFICATIONS permission (API 33+)
      before scheduling. If denied, the reminders section shows an explanation
      and a link to system settings.
- [ ] On iOS, the app requests notification authorization. If denied, the
      reminders section shows an explanation and a link to system settings.

## API contract

This feature introduces no HTTP endpoints and does not change the backend API.
All scheduling and condition checking is local. The quota condition uses the
locally cached `RecordQuotaState` already fetched during normal app usage.

## Data model changes

New persisted preferences (local key-value storage):

- `remindersEnabled` — boolean, default `true`

The morning (09:00) and evening (20:00) times are hardcoded constants, not
persisted preferences.

No changes to the entry model or database schema.

## Dependencies

- [ ] Local notification scheduling (platform-specific or a cross-platform
      Flutter plugin such as `flutter_local_notifications`).
- [ ] Existing settings screen.
- [ ] Notification permission handling on Android 13+ and iOS.
- [ ] Access to local entry database to check "any entry today" for the
      morning condition.
- [ ] Access to cached `RecordQuotaState` to check remaining quota for the
      evening condition.

## UX / design references

No external design reference required. The reminders section should follow the
existing settings screen layout: toggles and time displays consistent with
current app styling.

## Non-functional requirements

- **Performance:** Scheduling local notifications is negligible. The condition
  check at fire time reads from local storage only — no network call.
- **Security:** Notification content must not include entry text, transcripts,
  or any personal data. Notification bodies are fixed, generic strings.
- **Reliability:** Reminders must survive app kill, device reboot, and time
  zone changes. The scheduling mechanism must re-register alarms on boot
  (Android) or rely on the platform's built-in repeat scheduling (iOS).
  If cached quota data is unavailable when the evening reminder fires, the
  notification should fire (fail-open: better to remind than to miss).

## Out of scope

- Configurable reminder times.
- More than two reminders or user-defined additional reminders.
- Smart or context-aware reminder timing (e.g., based on location or activity).
- Reminder messages that vary or include AI-generated prompts.
- Snooze or "remind me later" from the notification.
- Notification actions beyond tapping to open the app.
- Weekly or non-daily schedules.
- "On This Day" notifications (covered by spec 051).
- Notification sound or vibration customization.
- Do Not Disturb or quiet hours logic beyond the system's own DND.
- Fetching fresh quota from the backend at fire time — uses cached data only.

## Open questions

None.
