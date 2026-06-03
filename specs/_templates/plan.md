# Implementation Plan: [Feature Name]

> **Feature number:** NNN
> **Spec:** [`spec.md`](spec.md)
> **Author:** [name]
> **Date:** YYYY-MM-DD

---

## Approach summary

_One paragraph describing the chosen implementation strategy.
Reference the spec's acceptance criteria and explain how this plan satisfies them._

## Architecture decisions

_Document key technical choices and their rationale._

| Decision                       | Choice         | Rationale                          |
| ------------------------------ | -------------- | ---------------------------------- |
| [e.g., Validation approach]    | [e.g., Zod]   | [e.g., Runtime + static typing]    |
| [e.g., Storage migration]      | [e.g., None]  | [e.g., JSON store sufficient]      |

## File changes

_List every file that will be created or modified._

| File                                | Action   | Description                        |
| ----------------------------------- | -------- | ---------------------------------- |
| `src/routes/example.ts`             | Create   | New route handler                  |
| `src/controllers/example.ts`        | Create   | Business logic and validation      |
| `src/types/example.ts`              | Modify   | Add new fields or types            |

## API contract details

_Expand on the spec's API contract with implementation specifics:
middleware, validation rules, response headers, pagination strategy._

## Data model changes

_Show the before/after for any type changes.
Include migration steps for `features.json` if data shape changes._

### Before

```typescript
// existing type
```

### After

```typescript
// modified type
```

### Migration

_Steps to migrate existing data (if applicable)._

## Test strategy

_Define how this feature will be validated._

### Automated tests

_List the test cases that will be written.
Indicate test type: unit, integration, or contract._

| Test case                                | Type        | File                        |
| ---------------------------------------- | ----------- | --------------------------- |
| [e.g., Returns 400 for missing key]      | Integration | `tests/features.test.ts`    |
| [e.g., Backstage YAML includes new field]| Unit        | `tests/backstageMapper.test.ts` |

### Manual verification

_Steps for manual validation if automated tests don't fully cover the feature._

1. Start the development server.
2. [Step 2]
3. [Step 3]

## Integration notes

_Describe any integration points with other services, systems, or modules.
Note any contract changes that affect downstream consumers._

## Rollout & migration

_How will this be deployed?
Any backward-compatibility concerns?
Feature flags needed?_

## Risks & mitigations

| Risk                                   | Likelihood | Impact | Mitigation                    |
| -------------------------------------- | ---------- | ------ | ----------------------------- |
| [e.g., Breaking existing consumers]    | Medium     | High   | [e.g., Version the endpoint]  |

## Open items from spec

_Carry forward any unresolved questions from `spec.md` that affect implementation._
