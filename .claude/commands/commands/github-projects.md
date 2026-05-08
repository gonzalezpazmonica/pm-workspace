---
name: github-projects
description: Integración con GitHub Projects v2 para gestión ágil desde pm-workspace
developer_type: all
agent: task
context_cost: high
---

# /github-projects

> 🦉 Savia gestiona tus sprints directamente desde GitHub Projects.

---

## Cargar perfil de usuario

Grupo: **Infrastructure** — cargar:

- `identity.md` — nombre
- `projects.md` — repos y projects vinculados
- `preferences.md` — platform_preference

---

## Subcomandos

- `/github-projects connect {owner/repo}` — vincular un proyecto
- `/github-projects sync` — sincronizar estado actual
- `/github-projects board` — ver tablero Kanban actual
- `/github-projects status` — verificar conexión

---

## Flujo

### Paso 1 — Conectar con GitHub Projects v2

```
🔗 GitHub Projects Setup

  Requisitos:
  ├─ gh CLI autenticado (gh auth status)
  ├─ Repo: {owner}/{repo}
  └─ Project: seleccionar de lista existente o crear nuevo

  API: GraphQL (Projects v2 API)
  Auth: token de gh CLI (scope: project)
```

### Paso 2 — Mapeo de campos

```
📋 Campo Mapping — GitHub Projects ↔ pm-workspace

  GitHub Projects   → pm-workspace
  ──────────────────────────────────
  Issue             → PBI
  Draft Issue       → PBI (draft)
  Pull Request      → linked PR
  Iteration         → Sprint
  Status (field)    → State
  Labels            → Tags / Area
  Milestone         → Release
  Estimate (field)  → Story Points
```

### Paso 3 — Vista de tablero

```
📊 Board — {proyecto} — Sprint {N}

  📥 To Do (8)     | 🔄 In Progress (4) | ✅ Done (12)
  ─────────────────|─────────────────────|──────────────
  #45 Login UI     | #42 API Auth   3SP  | #38 DB Setup
  #46 Tests  2SP   | #43 Cache     5SP   | #39 CI/CD
  #47 Docs   1SP   | #44 Search    3SP   | #40 Logging
  ...              | #41 Export    2SP   | ...
```

### Paso 4 — Operaciones desde pm-workspace

Crear issues, mover entre columnas, asignar, estimar —
todo desde comandos Savia sin abrir GitHub UI.

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: github_projects
repo: "org/sala-reservas"
project_id: 12
items_total: 24
sprints_active: 1
last_sync: "2026-03-02T11:00:00Z"
```

---

## Restricciones

- **NUNCA** crear issues sin confirmación del usuario
- **NUNCA** cerrar issues/PRs automáticamente
- **NUNCA** modificar project settings (columnas, fields) sin permiso
- Requiere `gh` CLI autenticado — no PATs manuales
- GraphQL API tiene rate limits — respetar y cachear resultados
