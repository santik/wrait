# Spec-Driven Development Workflow

This document describes the spec-driven development (SDD) process used in this project.

## What is Spec-Driven Development?

SDD inverts the traditional development flow. Instead of jumping straight to
code, we start with a specification that defines _what_ we're building and
_why_. Code becomes the output of a structured plan, not the starting point.

**Key idea:** specifications are the source of truth. Code serves the spec.

## Why we use it

- **Prevents scope creep** — acceptance criteria are agreed before coding starts.
- **Enables AI-assisted development** — AI agents work better with structured
  specs than with vague instructions.
- **Improves traceability** — every task links back to a spec, which links back
  to the original requirements.
- **Reduces rework** — catching design issues in a spec is cheaper than fixing
  them in code.

## The six phases

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌─────────────┐
│  Specify  │──▶│  Clarify │──▶│   Plan   │──▶│  Tasks   │──▶│  Analyze │──▶│  Implement  │
│ (what/why)│   │  (auto)  │   │  (how)   │   │ (action) │   │  (auto)  │   │   (code)    │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘   └─────────────┘
      ▲                                                                             │
      └──────────────────────── feedback loop ────────────────────────────────────┘
```

### Phase 1: Specify

**Input:** an idea or feature request.
**Output:** `spec.md` — a complete feature specification.

1. Create a new folder: `specs/NNN-feature-name/`
2. Copy `specs/_templates/spec.md` into it.
3. Fill in all sections: overview, user stories, acceptance criteria,
   API contract, data model changes, NFRs.
4. Mark status as **Draft** when complete.

**Key questions to answer:**
- What problem does this solve?
- Who are the users and what are they trying to achieve?
- What does "done" look like? (acceptance criteria)
- What are the API request/response shapes?

**Gate:** present the draft spec to the user and obtain explicit approval before
proceeding to the Clarify phase.

### Phase 2: Clarify _(automatic)_

**Input:** a draft `spec.md`.
**Output:** a refined, unambiguous `spec.md` ready for planning.

The agent automatically reviews the spec for underspecified areas and asks
targeted questions before proceeding. This gate prevents planning against an
incomplete spec.

Questions the agent will surface:
- Are there acceptance criteria that are vague or untestable?
- Are there missing error cases or edge scenarios?
- Are there implicit assumptions about existing behaviour?
- Are there unresolved open questions in the spec?

Once all ambiguities are resolved, `spec.md` is updated and marked **Approved**.

**Gate:** present the finalised spec summary to the user and obtain explicit
approval before proceeding to the Plan phase.

### Phase 3: Plan

**Input:** an approved `spec.md`.
**Output:** `plan.md` — a detailed implementation plan.

1. Copy `specs/_templates/plan.md` into the feature folder.
2. Document architecture decisions with rationale.
3. List every file that will be created or modified.
4. Define the test strategy.
5. Assess risks and plan mitigations.

**Key questions to answer:**
- What is the simplest approach that satisfies the spec?
- What files change?
- How will this be tested?
- Are there backward-compatibility risks?

**Gate:** present the plan to the user and obtain explicit approval before
proceeding to the Tasks phase.

### Phase 4: Tasks

**Input:** an approved `plan.md`.
**Output:** `tasks.md` — an actionable, ordered checklist.

1. Copy `specs/_templates/tasks.md` into the feature folder.
2. Break the plan into small, concrete tasks.
3. Group tasks into sequential phases.
4. Mark parallelizable tasks with `[P]`.
5. Note dependencies between groups.

**Key questions to answer:**
- Can any tasks run in parallel?
- What is the critical path?
- What is the validation evidence for "done"?

**Gate:** present the task list to the user and obtain explicit approval before
proceeding to the Analyze phase.

### Phase 5: Analyze _(automatic)_

**Input:** `spec.md`, `plan.md`, and `tasks.md`.
**Output:** a consistency report and, if needed, corrections to the task list.

The agent automatically cross-checks all three artifacts before any code is
written. This gate catches misalignments early.

The agent checks:
- Every acceptance criterion in `spec.md` is covered by at least one task.
- Every architectural decision in `plan.md` is reflected in the task list.
- No tasks contradict the spec or introduce unplanned scope.
- Dependencies between task groups are correctly ordered.

If gaps or contradictions are found, tasks are corrected before proceeding.

**Gate:** present the analysis results (and any corrections) to the user and
obtain explicit approval before proceeding to the Implement phase.

### Phase 6: Implement

**Input:** `tasks.md`.
**Output:** working code, tests, and validation evidence.

1. Create a feature branch following the project's branching convention.
2. Work through tasks in order, checking them off.
3. Follow the project's commit conventions.
4. Record validation evidence in `tasks.md` (test output, command results).
5. Verify the build succeeds.

## Integration with git conventions

| SDD artifact         | Git artifact                               |
| -------------------- | ------------------------------------------ |
| Feature folder name  | Maps to the branch description             |
| Work item in spec    | Must match branch and commit work-item IDs |
| Spec status          | Tracks alongside the PR lifecycle          |
| Validation evidence  | Included in PR description or linked       |

Branch format: `<type>/<description>-#<work-item>`
Commit format: `type(scope): summary #<work-item>`

## Working with AI agents

The SDD workflow is designed to run end-to-end from a single agent prompt.
Given a feature description, the agent executes all six phases automatically:

1. Writes `spec.md` from the feature description.
2. **Waits for user approval** of the draft spec.
3. **Runs the Clarify phase** — asks targeted questions, updates the spec.
4. **Waits for user approval** of the finalised spec.
5. Writes `plan.md` from the approved spec.
6. **Waits for user approval** of the plan.
7. Writes `tasks.md` from the plan.
8. **Waits for user approval** of the task list.
9. **Runs the Analyze phase** — verifies cross-artifact consistency.
10. **Waits for user approval** of the analysis results before implementing.
11. Implements tasks group by group, recording validation evidence.

**Every phase transition requires explicit user approval.** The agent must never
automatically advance to the next phase without a clear confirmation from the
user.

### Supporting files

- **AGENTS.md** (repo root) gives agents the project context they need.
- **constitution.md** (repo root) defines the non-negotiable principles.
- **Spec templates** provide structured input that AI agents can fill in
  from a high-level description.

## Definition of Done

A feature is complete when:

- [ ] All acceptance criteria in `spec.md` are met.
- [ ] All tasks in `tasks.md` are checked off.
- [ ] Validation evidence is recorded in `tasks.md`.
- [ ] The project builds and all tests pass.
- [ ] Spec status is updated to **Complete**.

## Quick reference

| What                    | Where                                           |
| ----------------------- | ----------------------------------------------- |
| Start a new feature     | `specs/README.md`                               |
| Spec template           | `specs/_templates/spec.md`                      |
| Plan template           | `specs/_templates/plan.md`                      |
| Tasks template          | `specs/_templates/tasks.md`                     |
| Project principles      | `constitution.md`                               |
| Agent instructions      | `AGENTS.md`                                     |
