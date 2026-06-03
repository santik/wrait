# Feature Specification: [Feature Name]

> **Feature number:** NNN
> **Status:** Draft | Approved | In Progress | Complete | Superseded
> **Author:** [name]
> **Date:** YYYY-MM-DD
> **Work item:** #[work-item-number]

## Status history

| Date       | Status      | Author | Notes                    |
| ---------- | ----------- | ------ | ------------------------ |
| YYYY-MM-DD | Draft       | [name] | Initial spec created     |

---

## Overview

_One or two paragraphs describing the feature at a high level.
What does it do? Who benefits? Why is it needed now?_

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

_List the user stories this feature addresses._

- As a [role], I want [goal] so that [benefit].
- As a [role], I want [goal] so that [benefit].

## Acceptance criteria

_Concrete, testable conditions that must be true when the feature is complete._

- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

## API contract

_Define the HTTP endpoints this feature introduces or modifies.
Include method, path, request body, response shape, and error cases._

### `METHOD /path`

**Request:**

```json
{
  "field": "type — description"
}
```

**Response (success):**

```json
{
  "field": "type — description"
}
```

**Error responses:**

| Status | Body                          | When                        |
| ------ | ----------------------------- | --------------------------- |
| 400    | `{ "error": "..." }`         | Invalid input               |
| 404    | `{ "error": "..." }`         | Resource not found          |
| 409    | `{ "error": "..." }`         | Conflict (duplicate key)    |

## Data model changes

_Describe any additions or modifications to the data model.
Include field names, types, and whether existing data needs migration._

## Dependencies

_List features, libraries, or external systems this depends on._

- [ ] [Dependency 1]
- [ ] [Dependency 2]

## UX / design references

_Link to Figma files, wireframes, or design documents if applicable._

## Non-functional requirements

- **Performance:** [e.g., response time targets, throughput, concurrency]
- **Security:** [e.g., input validation, authentication, authorization]
- **Reliability:** [e.g., error handling, graceful degradation, data integrity]
- **Scalability:** [e.g., expected load, data volume, growth projections]
- **Observability:** [e.g., logging requirements, metrics, tracing]

## Out of scope

_Explicitly list what this feature does NOT cover to prevent scope creep._

## Open questions

_Track unresolved decisions here. Move to the relevant section once resolved._

- [ ] [Question 1]
