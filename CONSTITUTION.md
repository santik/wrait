# Constitution

> Governing principles for this project.
> All development — human or AI-assisted — must align with these principles.

> _TODO: Review these principles and adapt them to your project's needs before starting development._

## 1. Spec-first development

Every non-trivial change starts with a specification, not with code.
Follow the **specify → clarify → plan → tasks → analyze → implement** loop documented in
[`docs/spec-driven-workflow.md`](docs/spec-driven-workflow.md).

Code is the output of the plan, not the starting point.

### Artifact responsibilities

- **`spec.md`** — defines _what_ and _why_. Specs must be **purely functional
  and technology-agnostic**. They describe the problem, user needs, acceptance
  criteria, and constraints — never the solution. Do not prescribe frameworks,
  libraries, or implementation approaches. If a user mentions a specific
  technology, capture the underlying need, not the technology itself.
- **`plan.md`** — defines _how_. This is where technology choices are made,
  evaluated, and justified with rationale. Every significant decision must
  include why it was chosen over alternatives.
- **`tasks.md`** — defines _what to do, in what order_. Actionable,
  ordered implementation steps derived from the plan. Each task must be
  concrete enough to implement without further clarification.

### Phase gates

Every phase transition requires **explicit user approval**. Never advance
to the next phase without clear confirmation from the user. Present your
output, then stop and wait.

## 2. Simplicity over cleverness

Choose the simplest solution that correctly satisfies the spec.
Avoid over-engineering, premature abstractions, and unnecessary dependencies.
If the simple approach works, ship it.

## 3. Reuse over rebuild

Before building, check if an existing module, library, or pattern already
solves the problem. Before creating a new utility, check if an existing one
can be extended. Duplication is a defect.

## 4. Validate at the boundary

- Validate all inputs at system boundaries — never trust external data.
- Return clear, structured error responses.
- Error messages must never leak implementation details or stack traces.

## 5. Security by default

- Apply rate limiting on all public endpoints.
- Restrict CORS to known origins in production.
- Never commit secrets — use environment variables.
- Keep dependencies up to date and audit regularly.

## 6. Version control conventions

- Use the conventional commits format: `type(scope): summary`.
- Branch names should be descriptive: `<type>/<short-description>`.
- Reference work item numbers in commits and branches when applicable.

## 7. Data model evolution

- Schema changes must be documented in the plan before implementation.
- Show before/after for any type or schema change.
- Include migration steps when existing data is affected.
- Prefer backward-compatible changes over breaking ones.

## 8. Test evidence required

- Every feature spec must include a **test strategy** section.
- Implementation is not “done” until validation evidence exists
  (automated tests, manual test log, or API contract verification).

