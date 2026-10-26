# Feature Specification: Quota Abuse Protection (client)

> **Feature number:** 059
> **Status:** Approved
> **Author:** santik.alex@gmail.com
> **Date:** 2026-10-21
> **Work item:** n/a

## Status history

| Date       | Status | Author                 | Notes                                                      |
| ---------- | ------ | ---------------------- | ---------------------------------------------------------- |
| 2026-10-21 | Draft  | santik.alex@gmail.com  | Initial spec created                                       |
| 2026-10-21 | Draft  | santik.alex@gmail.com  | Clarified: launch quota via `/register`, credential/id roles |
| 2026-10-21 | Approved | santik.alex@gmail.com | Clarify complete; approved for planning                      |

---

## Overview

The app registers with the backend at launch and then calls paid endpoints
(transcription, cleanup, tagging), today identifying itself only with a
device identifier it supplies and a shared access secret compiled into the
build. The backend is being changed (see backend feature
`004-quota-abuse-protection`) so that quota is keyed on a **server-issued
credential** rather than on the self-asserted device identifier, and so that
new registrations are rate-limited per network origin.

This feature is the client counterpart: the app must transparently obtain,
securely store, and present that credential on every quota-protected call,
recover automatically when the credential is missing or rejected, and surface
the new rate-limit condition without alarming the user or breaking the
draft-first recording flow. For a normal user nothing should change
perceptibly.

> **Reminder:** This spec is purely functional and technology-agnostic. The
> secure-storage mechanism, credential header, and client package choices
> belong in `plan.md`.

## User stories

- As a user, I want the app to obtain and use whatever credential the backend
  requires without any action from me, so that recording and transcription keep
  working exactly as before.
- As a user whose credential becomes missing or is rejected, I want the app to
  recover on its own where possible, so that I am not stuck unable to transcribe.
- As a user on a shared or constrained network, if the backend temporarily
  refuses a new registration, I want a clear, non-alarming message and automatic
  recovery, rather than a generic failure.
- As an existing user upgrading the app, I want to keep all my local entries and
  drafts while the app transparently moves to the new credential.

## Acceptance criteria

- [ ] On first launch the app obtains the server-issued credential and stores it
      so it survives app restarts and is not readable as plain preferences.
- [ ] Every quota-protected call (transcribe, cleanup, tag) presents the stored
      credential.
- [ ] If a quota-protected call is rejected because the credential is missing or
      invalid, the app re-registers once and retries the call transparently; if
      recovery fails, it falls back to the existing authentication-failure user
      experience.
- [ ] A registration rate-limit response is surfaced as a distinct, retriable
      state (not a generic error) and does not corrupt or discard draft-first
      entries.
- [ ] The app displays its quota at startup from the `/register` response, in
      both the first-launch (credential issued) and returning-launch (credential
      verified) cases, with no change to the existing startup quota display.
- [ ] After the first successful registration, launching the app presents the
      stored credential (returning-launch path) and does not trigger a new
      identity creation.
- [ ] An existing user upgrading from a build that used only the device
      identifier transparently obtains the new credential on next launch — the
      credential is bound to their existing device identifier server-side — so
      their accrued quota carries over and no local data or pending drafts are
      lost.
- [ ] No credential value is ever written to logs or crash reports.
- [ ] The happy path introduces no new user-visible step, prompt, or delay
      beyond what registration already costs today.

## API contract

The app consumes the updated backend contract (`api/wrait-backend.yaml`) for
feature `004`. The generated client is regenerated from that contract. Request
and response shapes are defined by the backend spec; this feature does not
introduce endpoints of its own. Concrete header/field wiring is deferred to
`plan.md`.

## Data model changes

- A new securely-stored **credential** value on the device. Once issued, the
  credential is what authorizes quota-protected calls; the plain device
  identifier is used only at registration time (to request a credential, and to
  let the server bind the credential to an existing device during migration).
  The secure-storage mechanism is decided in `plan.md`.
- No change to the encrypted local entry database schema.

## Dependencies

- [ ] Backend feature `004-quota-abuse-protection` — its contract must be
      published first; this client work consumes it.
- [ ] Existing preferences / secure-storage infrastructure and the device-id
      method channel.
- [ ] Regeneration of the generated backend API client from the updated
      OpenAPI contract (`npm run build`).

## UX / design references

No new screens. Reuses the existing authentication-failure and transient-error
presentation already shown for registration failures. Any new copy for the
rate-limit state is a small addition to existing localized strings.

## Non-functional requirements

- **Performance:** credential retrieval and attachment must not add perceptible
  latency to recording or transcription.
- **Security:** the credential must be held in secure device storage and never
  logged, exported, or included in feedback/crash payloads.
- **Reliability:** the draft-first rule must remain intact — an entry is still
  persisted before any network call — and credential recovery must not drop a
  recording in progress.
- **Compatibility:** upgrade from the current version must be seamless for
  existing users and preserve local data and drafts.
- **Observability:** credential-recovery and rate-limit events should be
  distinguishable in existing diagnostics without exposing the credential.

## Out of scope

- Platform attestation (Play Integrity / App Attest) integration.
- User accounts, sign-in, email/password, or any PII collection.
- Changes to recording, cleanup, or draft logic beyond what credential handling
  requires.
- Backend credential issuance/verification itself (covered by feature `004`).

## Non-functional / constitutional verification requirements

- [ ] `integration_test` coverage is planned for every in-scope user flow:
  - first-launch registration followed by a successful transcription;
  - a quota-protected call rejected for an invalid credential, followed by
    automatic re-registration and successful retry;
  - a registration rate-limit response surfaced as a retriable state with
    drafts preserved.
- [ ] Final approval requires validation on both an Android emulator and an iOS
      simulator, unless an explicit planning-time exception is approved.

## Resolved clarifications

- **Startup quota:** obtained from the `/register` launch response (unchanged
  field); credential issuance on first launch and verification on later launches
  both return the quota snapshot, so the existing startup display is preserved.
- **Credential vs. device id:** the credential authorizes quota-protected calls
  once issued; the device identifier is used only at registration/migration.
- **Migration:** a one-time silent re-registration on upgrade is acceptable; the
  server binds the credential to the existing device id so quota carries over.
- **Secure-storage failure:** if secure storage is unavailable or returns no
  credential at a call site, the app **re-registers and retries** the call
  transparently (the backend's Mode A rate limit remains the backstop against
  loops); it does not fail closed on the first miss.

## Open questions

- [ ] Which concrete secure-storage mechanism to use (a secure-storage package
      vs. the existing platform keystore via the method channel) is deferred to
      `plan.md` as an implementation choice; it does not block spec approval.
