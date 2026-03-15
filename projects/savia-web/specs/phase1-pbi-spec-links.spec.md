# Spec: PBI ↔ Spec Bidirectional Linkage

## Metadatos
- project: savia-web
- phase: 1 — Backlog Data Model
- feature: pbi-spec-links
- status: pending
- developer_type: agent
- depends: phase1-tasks-entities (tasks reference specs too)

## Objective

Establish formal bidirectional links between PBIs and the specs generated from them. Currently there is no traceability between a PBI and its specs — you cannot know which specs implement a PBI, nor which PBI a spec belongs to.

## Data Model Changes

### PBI frontmatter — new field `specs`

```yaml
---
id: PBI-004
title: "Backlog funcional"
# ... existing fields ...
specs:
  - path: "specs/phase2-backlog-ui.spec.md"
    status: approved           # draft | approved | implemented | verified
  - path: "specs/phase2-backlog-kanban.spec.md"
    status: draft
---
```

`specs` is an array of objects with `path` (relative to project root) and `status`.

### Spec frontmatter — new field `parent_pbi`

```yaml
---
# ... existing spec metadatos ...
parent_pbi: PBI-004            # PBI that originated this spec
---
```

### Task frontmatter — existing `spec` field

Already defined in phase1-tasks-entities: `spec: "specs/..."`. This creates the chain: PBI → Spec → Task.

### Full traceability chain

```
PBI-004
├── specs: [phase2-backlog-ui.spec.md (approved)]
│   ├── parent_pbi: PBI-004
│   └── tasks: TASK-004-001, TASK-004-002
└── specs: [phase2-backlog-kanban.spec.md (draft)]
    └── parent_pbi: PBI-004
```

## Implementation

### 1. Command: `/pbi-specs {pbi-id}`

Lists all specs linked to a PBI with their status.

```
/pbi-specs PBI-004

PBI-004: Backlog funcional
  Specs:
  ✅ specs/phase2-backlog-ui.spec.md      — approved
  📝 specs/phase2-backlog-kanban.spec.md  — draft

  Coverage: 2 specs, 1 approved, 1 draft
```

### 2. Command: `/spec-link {spec-path} {pbi-id}`

Links a spec to a PBI bidirectionally:
1. Adds entry to PBI's `specs:` array
2. Sets `parent_pbi:` in spec frontmatter
3. Logs change in PBI's `## Historial`

### 3. Validation hook: `spec-link-validate.sh`

On commit, verify bidirectional consistency:
- Every PBI `specs:` entry → the spec file exists AND has matching `parent_pbi`
- Every spec `parent_pbi:` → the PBI file exists AND lists this spec in `specs:`
- Violations → warning (not blocking, to allow work-in-progress)

### 4. Auto-linking in `/spec-generate`

When `/spec-generate` creates a spec from a task/PBI, it should auto-set `parent_pbi` and add to the PBI's `specs:` array.

### 5. Bridge API endpoint

```
GET /backlog/pbi/{id}/specs     → [{ path, status, title }]
GET /backlog/specs/{path}/pbi   → { pbi_id, pbi_title }
```

## Spec status lifecycle

```
draft → approved → implemented → verified
```

| Status | Meaning |
|--------|---------|
| `draft` | Spec written, not yet reviewed |
| `approved` | Spec reviewed and approved for implementation |
| `implemented` | Code written, not yet verified |
| `verified` | Implementation passes all acceptance criteria |

Status changes are logged in the PBI's `## Historial`.

## Acceptance Criteria

- [ ] AC-1: PBI frontmatter supports `specs:` array with path and status
- [ ] AC-2: Spec frontmatter supports `parent_pbi:` field
- [ ] AC-3: `/pbi-specs PBI-004` lists all linked specs with status
- [ ] AC-4: `/spec-link specs/foo.spec.md PBI-004` updates both files
- [ ] AC-5: Validation hook detects broken bidirectional links
- [ ] AC-6: `/spec-generate` auto-links to parent PBI
- [ ] AC-7: Bridge endpoints return spec-PBI relationships
- [ ] AC-8: Spec status changes are logged in PBI historial
