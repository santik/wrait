# Tasks: [Feature Name]

> **Feature number:** NNN
> **Plan:** [`plan.md`](plan.md)
> **Author:** [name]
> **Date:** YYYY-MM-DD

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

_Tasks are organized into sequential groups.
Tasks within the same group marked `[P]` can be worked on in parallel._

### Group 1: Foundation

_Set up types, interfaces, and data model changes._

- [ ] [P] Task description — `file/path.ts`
- [ ] [P] Task description — `file/path.ts`

### Group 2: Core implementation

_Implement the main logic, routes, and controllers._

- [ ] Task description — `file/path.ts`
  - Depends on: Group 1
- [ ] [P] Task description — `file/path.ts`
- [ ] [P] Task description — `file/path.ts`

### Group 3: Integration

_Backstage mapping, data migration, and cross-cutting concerns._

- [ ] Task description — `file/path.ts`
  - Depends on: Group 2

### Group 4: Validation

_Tests, manual verification, and documentation._

- [ ] Write automated tests per plan's test strategy
- [ ] Manual verification steps from plan
- [ ] Update documentation if public API changed
- [ ] Verify the build succeeds with no errors

## Completion criteria

All tasks checked, `yarn build` clean, and validation evidence documented
in this file or linked from here.

## Validation evidence

_Record test results, screenshots, or curl output here when complete._

```
# Example:
$ curl http://localhost:4000/features | jq length
7
```

## Notes

_Any observations, decisions, or deviations from the plan during implementation._
