# wrait — Project Context

**Stack:** android | none | kotlin

1 routes | 0 models | 0 env vars | 0 import links

**API areas:** /MainActivity

---

## Instructions for Codex

Act as a senior android engineer. You know everything around android development. You have deep knowledge about software architecture, testing and software development best practices.

### Two-Step Rule (mandatory)
**Step 1 — Orient:** Use wiki articles to find WHERE things live.
**Step 2 — Verify:** Read the actual source files listed in the wiki article BEFORE writing any code.

Wiki articles are structural summaries extracted by AST. They show routes, models, and file locations.
They do NOT show full function logic, middleware internals, or dynamic runtime behavior.
**Never write or modify code based solely on wiki content — always read source files first.**

Read in order at session start:
1. `.codesight/wiki/index.md` — orientation map (~200 tokens)
2. `.codesight/wiki/overview.md` — architecture overview (~500 tokens)
3. Domain article (e.g. `.codesight/wiki/auth.md`) → check "Source Files" section → read those files
4. `.codesight/CODESIGHT.md` — full context map for deep exploration
5. `functional_description.md` — detailed functional description of app behavior

Routes marked `[inferred]` in wiki articles were detected via regex — verify against source before trusting.
If any source file shows ⚠ in the wiki, re-run `npx codesight --wiki` before proceeding.

## Spec-driven development workflow

This project follows a **specify → clarify → plan → tasks → analyze → implement** loop.
All artifact responsibilities and phase gate rules are defined in
[`constitution.md`](CONSTITUTION.md). Read it before starting any feature work.

Before starting any non-trivial feature:

1. Copy templates from `specs/_templates/` into a new `specs/NNN-feature-name/` folder.
2. Fill in `spec.md` — what and why.
3. **STOP. Present the draft spec and wait for explicit user approval.**
4. Clarify the spec — resolve ambiguities through agent questions.
5. **STOP. Present the finalised spec and wait for explicit user approval.**
6. Fill in `plan.md` — how (architecture, contracts, test strategy).
7. **STOP. Present the plan and wait for explicit user approval.**
8. Fill in `tasks.md` — actionable checklist.
9. **STOP. Present the tasks and wait for explicit user approval.**
10. Analyze — verify cross-artifact consistency before coding.
11. **STOP. Present the analysis and wait for explicit user approval.**
12. Implement against the tasks, updating status as you go.

> **Hard rule:** After completing any phase output, you MUST stop and wait for
> the user to respond. Do not continue to the next phase, even if you believe
> approval is implied. Silence is not approval.

Full process: see [`docs/spec-driven-workflow.md`](docs/spec-driven-workflow.md).