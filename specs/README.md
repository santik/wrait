# specs/

This directory holds feature specifications following the
**Spec-Driven Development** workflow.

## Directory structure

```
specs/
├── _templates/          # Copy these to start a new feature
│   ├── spec.md          # Feature specification (what & why)
│   ├── plan.md          # Implementation plan (how)
│   └── tasks.md         # Task breakdown (actionable checklist)
├── 001-feature-name/    # First feature
│   ├── spec.md
│   ├── plan.md
│   └── tasks.md
├── 002-another-feature/ # Second feature
│   └── ...
└── README.md            # This file
```

## Starting a new feature

1. Determine the next feature number by checking existing folders.
2. Create a folder: `specs/NNN-short-description/`
   — use lowercase, hyphens, no spaces.
3. Copy all three templates from `_templates/` into your new folder.
4. Fill them in order: `spec.md` → `plan.md` → `tasks.md`.
5. Create a feature branch: `feat/short-description` (append `-#<work-item>` if one exists).

## Naming conventions

| Element             | Format                                  | Example                    |
| ------------------- | --------------------------------------- | -------------------------- |
| Folder name         | `NNN-kebab-case-description`            | `001-crud-api`             |
| Feature number      | Zero-padded, incrementing               | `001`, `002`, ..., `1000`  |
| Branch              | `<type>/<description>[-#<work-item>]`   | `feat/crud-api` or `feat/crud-api-#42` |
| Spec file           | Always `spec.md`                        |                            |
| Plan file           | Always `plan.md`                        |                            |
| Tasks file          | Always `tasks.md`                       |                            |

## Lifecycle

- **Draft** — spec is being written, not yet reviewed.
- **Approved** — spec has been reviewed and accepted.
- **In progress** — tasks are being implemented.
- **Complete** — all tasks done, validation evidence collected.
- **Superseded** — replaced by a newer spec.

Track the current status at the top of each `spec.md`.
