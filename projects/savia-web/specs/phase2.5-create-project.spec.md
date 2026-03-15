---
id: "phase2.5-create-project"
title: "Create Project from Web — Modal + Scaffolding"
status: "approved"
developer_type: "agent-single"
parent_pbi: ""
---

# Create Project from Web

## Objetivo

Add a "+" button next to the project selector in the TopBar. Clicking it opens a modal form to create a new project. On submit, the Bridge creates the project folder with full scaffolding.

## Requisitos Funcionales

### RF-01: Create Project Button

- "+" icon button right of project selector in TopBar
- Opens a centered modal overlay

### RF-02: Modal Form Fields

| Field | Type | Required | Default |
|-------|------|----------|---------|
| Project name | text | yes | — |
| Description | textarea | no | — |
| Language/Stack | select | yes | (Vue, .NET, Java, Python, Go, Rust, PHP, Ruby, Other) |
| Project Manager | text (@handle) | yes | current user |
| Client name | text | no | — |
| Sprint duration | select | no | 2 weeks |
| Repository URL | text | no | — |

### RF-03: Scaffolding (Bridge POST `/projects`)

On submit, Bridge creates:

```
projects/{slug}/
├── CLAUDE.md              ← Generated from template with form data
├── backlog/
│   ├── _config.yaml       ← Default states, types, priorities
│   ├── pbi/               ← Empty
│   └── tasks/             ← Empty
├── specs/                 ← Empty
├── equipo.md              ← PM entry pre-filled
└── reglas-negocio.md      ← Empty template
```

### RF-04: Post-Creation

- Close modal
- Add new project to project selector
- Auto-select the new project
- Navigate to /backlog (empty state)

## Criterios de Aceptacion

- [ ] "+" button visible next to project selector
- [ ] Modal opens with all form fields
- [ ] Validation: name required, @handle format for PM
- [ ] Bridge creates folder structure on submit
- [ ] New project appears in selector immediately
- [ ] Project auto-selected and backlog page loads
