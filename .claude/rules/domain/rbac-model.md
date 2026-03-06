---
name: rbac-model
description: "Role-Based Access Control — 4-tier permission matrix with role inheritance and audit trail"
auto_load: false
paths: [".claude/commands/rbac-manager*", ".claude/skills/rbac-management/*"]
---

# Regla: RBAC File-Based (Role-Based Access Control)

> v2.12.0 — Multi-role governance framework for pm-workspace
> Basado en: NIST Role-Based Access Control (RBAC), Keycloak scope model

**Principio fundamental**: Cada usuario tiene un rol global y puede tener roles
adicionales por proyecto. Los permisos se heredan: Admin > PM > Contributor > Viewer.

## Cuatro roles estándar

| Rol | Permisos | Alcance | Ejemplo |
|---|---|---|---|
| **Admin** | Todo (comandos, rules, skills, deploy) | Global | CTO, Director de Ingeniería |
| **PM** | Sprint, backlog, reports, no deploy | Global o proyecto | Product Manager, Scrum Master |
| **Contributor** | Code, specs, tests, PRs, no org mgmt | Global o proyecto | Developer, QA, Tech Writer |
| **Viewer** | Read-only todo | Global | Stakeholder, CEO (auditoría) |

## Matriz de permisos

| Categoría | Comando | Admin | PM | Contributor | Viewer |
|---|---|---|---|---|---|
| **Sprint** | sprint-plan | ✅ | ✅ | ❌ | ❌ |
| | sprint-status | ✅ | ✅ | ✅ | ✅ |
| | sprint-review | ✅ | ✅ | ❌ | ❌ |
| **Backlog** | backlog-groom | ✅ | ✅ | ❌ | ❌ |
| | backlog-prioritize | ✅ | ✅ | ❌ | ❌ |
| | pbi-create | ✅ | ✅ | ❌ | ❌ |
| **Report** | report-executive | ✅ | ✅ | ❌ | ✅ |
| | report-capacity | ✅ | ✅ | ❌ | ✅ |
| | ceo-report | ✅ | ❌ | ❌ | ✅ |
| **Code** | pr-review | ✅ | ❌ | ✅ | ✅ |
| | spec-generate | ✅ | ❌ | ✅ | ❌ |
| | code-audit | ✅ | ❌ | ✅ | ✅ |
| **Deploy** | azure-pipelines apply | ✅ | ❌ | ❌ | ❌ |
| | infra-create | ✅ | ❌ | ❌ | ❌ |
| **Org** | team-orchestrator | ✅ | ❌ | ❌ | ❌ |
| | profile-setup | ✅ | ✅ | ✅ | ❌ |
| | rbac-manager | ✅ | ❌ | ❌ | ❌ |

## Role assignment schema

Cada usuario tiene su perfil de identidad con rol asignado:

```
.claude/profiles/{user-handle}/role.md
```

Contenido:
```yaml
---
role: "PM"              # Admin | PM | Contributor | Viewer
scope: "global"         # global | ["proj-a", "proj-b"]
granted_by: "admin"     # usuario que asignó el rol
granted_at: "2026-03-05T10:00:00Z"
---
```

## Role inheritance

La herencia es **estricta**: Admin incluye PM + Contributor + Viewer.

```
Admin (todo)
  ├── PM (sprint, backlog, reporting)
  ├── Contributor (code, specs, tests, PRs)
  └── Viewer (read-only)
```

Si un usuario tiene rol `PM`, NO puede ejecutar comandos `code-audit` (eso requiere `Contributor`).

## Scope: global vs. project-specific

**Global scope**: el usuario tiene el rol en TODOS los proyectos.
```yaml
scope: "global"
```

**Project scope**: el usuario tiene el rol solo en algunos proyectos.
```yaml
scope: ["sala-reservas", "erp-migration"]
```

Si intenta ejecutar comando en proyecto no-autorizado: **ERROR acceso denegado**.

## Enforcement: pre-command hook check

Antes de ejecutar CUALQUIER comando, verificar mediante hook `.claude/hooks/rbac-check.sh`:

1. Lee `.claude/profiles/{active-user}/identity.md` → obtiene `role`
2. Lee `.claude/profiles/{active-user}/role.md` → obtiene `scope`
3. Consulta matriz de permisos: ¿el rol puede ejecutar el comando?
4. Si `scope ≠ global`, verifica que el proyecto está en la lista
5. Si no tiene permiso → ERROR + sugerencia de rol necesario
6. Si tiene permiso → ejecutar + registrar en audit

Hook: `.claude/hooks/rbac-check.sh` (invocado en PreToolUse)

## Audit trail

Cada acción ejecutada se registra en:

```
output/rbac-audit.jsonl
```

Formato JSONL (una línea por acción):
```json
{"timestamp":"2026-03-05T10:15:00Z","user":"monica-gonzalez","command":"sprint-plan","allowed":true,"role":"PM","scope":"global","reason":""}
{"timestamp":"2026-03-05T10:30:00Z","user":"carlos-mendoza","command":"infra-create","allowed":false,"role":"Contributor","scope":"global","reason":"Admin only"}
```

Campos: `timestamp` (ISO 8601 UTC), `user` (handle activo), `command` (nombre comando),
`allowed` (boolean), `role` (del usuario), `scope` (global o proyecto), `reason` (si denegado).

## Integración con team-orchestrator

Los roles RBAC mapean con la estructura de equipos:
- Tech Lead → `Contributor` (a su equipo) + `Admin` (de sus specs)
- PM → `PM` (global) + `Contributor` (si hace code)
- Developer → `Contributor` (asignado a proyecto/equipo)

Comando `/team-orchestrator assign` asigna el rol RBAC automáticamente según
la función (`role: contributor | pm | tech-lead`).

## Configuración por proyecto

Un proyecto puede sobrescribir la matriz de permisos en `projects/{proyecto}/rbac-overrides.md`:

```yaml
# Solo PM del proyecto puede hacer sprint-plan (no solo global PMs)
overrides:
  sprint-plan:
    allowed_roles: ["Admin", "PM"]
    scope_enforcement: true
```

Sin sobrescrituras, usa la matriz global de `rbac-model.md`.
