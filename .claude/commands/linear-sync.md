---
name: linear-sync
description: Sincronización bidireccional con Linear — issues, cycles, métricas unificadas
developer_type: all
agent: task
context_cost: high
---

# /linear-sync

> 🦉 Savia conecta con Linear — sync bidireccional y métricas unificadas.

---

## Cargar perfil de usuario

Grupo: **Connectors** — cargar:

- `identity.md` — nombre, empresa
- `projects.md` — proyectos
- `preferences.md` — platform_preference

---

## Subcomandos

- `/linear-sync setup` — configurar conexión con Linear workspace
- `/linear-sync pull` — traer estado actual de Linear
- `/linear-sync push` — enviar cambios a Linear
- `/linear-sync status` — verificar conexión y métricas de sync
- `/linear-sync --dry-run` — simular sync sin ejecutar cambios

---

## Flujo

### Paso 1 — Configurar conexión

Datos necesarios: Linear API Key, Workspace, Team(s), Project(s).
Almacenamiento cifrado en `$HOME/.pm-workspace/linear-credentials`.

### Paso 2 — Mapeo de entidades

| Linear | pm-workspace |
|---|---|
| Project | Feature / Epic |
| Issue | PBI |
| Sub-issue | Task |
| Cycle | Sprint |
| Estimate | Story Points |
| Priority (1-4) | Business Value |
| Label | Tags |
| State | State (mapped) |

### Paso 3 — Sincronización bidireccional

1. Obtener issues de Linear (filtro por cycle, team, label)
2. Obtener work items de Azure DevOps (filtro por IterationPath)
3. Detectar correspondencias por `[LIN#ID]` en título
4. Calcular diff: nuevos, actualizados, conflictos
5. Presentar propuesta y confirmar antes de ejecutar

### Paso 4 — Webhooks opcionales

Configurar Linear webhooks para sync en tiempo real
via `/webhook-config add linear`.

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: linear_sync
workspace: "empresa-workspace"
teams_connected: 2
issues_synced: 89
cycles_mapped: 4
last_sync: "2026-03-02T09:15:00Z"
conflicts: 1
```

---

## Restricciones

- **NUNCA** almacenar API keys en texto plano
- **NUNCA** sincronizar sin confirmación del PM
- **NUNCA** crear issues en Linear automáticamente — siempre confirmar
- Conflictos de sync → resolución manual con sugerencia de Savia
- Respetar rate limits de Linear API (1500 req/hora)
- No eliminar issues en ningún sistema — solo crear y actualizar
