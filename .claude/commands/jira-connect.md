---
name: jira-connect
description: Conectar y sincronizar con Jira Cloud como alternativa a Azure DevOps
developer_type: all
agent: task
context_cost: high
---

# /jira-connect

> 🦉 Savia habla Jira — tus mismos workflows, nueva plataforma.

---

## Cargar perfil de usuario

Grupo: **Infrastructure** — cargar:

- `identity.md` — nombre, empresa
- `projects.md` — proyectos a conectar
- `preferences.md` — platform_preference

---

## Subcomandos

- `/jira-connect setup` — configurar conexión inicial con Jira Cloud
- `/jira-connect sync` — sincronizar estado actual (pull)
- `/jira-connect map` — mapear campos Jira ↔ pm-workspace
- `/jira-connect status` — verificar conexión y último sync

---

## Flujo

### Paso 1 — Configurar conexión

```
🔗 Jira Cloud Setup

  Datos necesarios:
  ├─ Jira URL: {empresa}.atlassian.net
  ├─ Email: {email registrado}
  ├─ API Token: generado en id.atlassian.com
  └─ Proyecto(s): {clave del proyecto, ej. SALA}

  Almacenamiento: $HOME/.pm-workspace/jira-credentials
  (cifrado con AES-256, mismo mecanismo que /backup)
```

### Paso 2 — Mapeo de campos

```
📋 Campo Mapping — Jira ↔ pm-workspace

  Jira              → pm-workspace
  ──────────────────────────────────
  Epic              → Feature
  Story             → PBI
  Sub-task          → Task
  Bug               → Bug
  Sprint            → Sprint (iteration)
  Story Points      → Story Points
  Priority          → Business Value
  Status            → State (mapped)
  Component         → Area Path
```

### Paso 3 — Sincronización bidireccional

```
🔄 Sync Status — {proyecto}

  Jira → pm-workspace:
    Sprints importados: {N}
    Items sincronizados: {N}
    Último sync: {timestamp}

  pm-workspace → Jira:
    Items actualizados: {N}
    Comentarios añadidos: {N}
    Conflictos: {N} (requieren resolución manual)
```

### Paso 4 — Comandos adaptados

Todos los comandos /sprint-*, /daily-*, /backlog-* funcionan
igual — Savia traduce internamente entre Jira y su modelo.

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: jira_connect
jira_url: "empresa.atlassian.net"
projects_connected: 2
items_synced: 147
last_sync: "2026-03-02T10:30:00Z"
conflicts: 0
```

---

## Restricciones

- **NUNCA** almacenar API tokens en texto plano
- **NUNCA** sobrescribir datos en Jira sin confirmación
- **NUNCA** sincronizar campos que el PM no ha mapeado explícitamente
- Sync bidireccional requiere confirmación por dirección
- Conflictos siempre se resuelven manualmente — Savia sugiere
