---
id: SPEC-054
status: PROPOSED
---

# SPEC-054 — Context Index System

**Status:** Draft | **Author:** Savia | **Date:** 2026-03-29

## Problem

pm-workspace stores context across dozens of locations: rules, skills, agents,
memory, profiles, project-specific docs, agent memory (3 levels), digest logs,
and more. Digesters (meeting-digest, pdf-digest, word-digest) need to know WHERE
to store extracted information. Savia needs to know WHERE to look when answering
questions. New team members have no map of the information architecture.

The existing rules (context-placement-confirmation.md, digest-traceability.md,
resource-resolution.md) define WHAT goes WHERE by confidentiality level, but there
is no single navigable index of all context locations with their purposes.

## Solution

Two auto-generated index files:

1. **Workspace-level** `.context-index/WORKSPACE.ctx` — maps global context
   (rules, skills, agents, profiles, memory) with intent-based lookups
2. **Per-project** `projects/{name}/.context-index/PROJECT.ctx` — maps
   project-specific context (business rules, teams, meetings, decisions)

## Design Principles

1. **Descriptive, not prescriptive** — maps what exists, does not create dirs
2. **Intent-indexed** — entries include `[intent]` for question-answering and
   `[digest-target]` for telling digesters where to put extracted info
3. **Plain text** — human-readable, no JSON/YAML, easily diffable
4. **Lightweight** — workspace <200 lines, project <100 lines
5. **Git-tracked at workspace level**, gitignored at project level

## Format

Each section has entries of three types:

```
[location]       path — description of what lives there
[intent: "..."]  → path or action to resolve user questions
[digest-target]  When extracting X from Y → store here
```

## Generation

`scripts/generate-context-index.sh` scans the workspace and produces indices:

- `--workspace` — regenerate WORKSPACE.idx only
- `--project NAME` — regenerate PROJECT.idx for one project
- No args — regenerate all (workspace + all projects)

The script detects existing directories and files. It does NOT create project
directories that do not exist. Missing optional paths are listed as `[optional]`.

## Integration Points

| Consumer | Uses |
|----------|------|
| **Group A (writers)**: meeting-digest, pdf-digest, word-digest, excel-digest, pptx-digest, visual-digest, sdd-spec-writer, tech-writer | `[digest-target]` entries to place extracted/generated content |
| **Group B (readers)**: architect, business-analyst, code-reviewer, security-*, coherence-validator, reflection-validator, dev-orchestrator, diagram-architect, drift-auditor, feasibility-probe, test-engineer, confidentiality-auditor | `[location]` and `[intent]` entries to find project context |
| **Group C (developers)**: all 12 language-specific developers | `[location]` entries to find specs and architecture |
| Savia question answering | `[intent]` entries |
| `/context-load` | WORKSPACE.idx for session priming |
| `/project-new` | PROJECT-TEMPLATE.idx for scaffold |
| Human onboarding | Both indices as orientation maps |

## Confidentiality

- WORKSPACE.ctx is N1 (public, git-tracked in `.context-index/`)
- PROJECT.ctx is N4 (project-level, gitignored via `projects/` rule)
- PROJECT-TEMPLATE.ctx is N1 (generic template, git-tracked)

## File Locations

```
.context-index/WORKSPACE.ctx          — generated, git-tracked
.context-index/PROJECT-TEMPLATE.ctx   — template, git-tracked
projects/{name}/.context-index/PROJECT.ctx — generated, gitignored
```

## Scope Limits

- Does not replace context-placement-confirmation.md (classification rules)
- Does not replace digest-traceability.md (processing log)
- Does not replace resource-resolution.md (@ reference resolution)
- Complements all three by providing the navigable map they lack

## Verification

`tests/evals/test-context-index.bats` — validates script, output format,
completeness, and template integrity. Minimum 10 tests.
