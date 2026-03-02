---
name: mcp-server
description: Expone las herramientas de Savia como MCP server para otros proyectos Claude Code
developer_type: all
agent: task
context_cost: high
---

# /mcp-server

> 🦉 Savia se convierte en herramienta disponible para otros proyectos.

---

## Cargar perfil de usuario

Grupo: **Infrastructure** — cargar:

- `identity.md` — nombre
- `preferences.md` — language
- `projects.md` — proyectos expuestos

---

## Subcomandos

- `/mcp-server start` — iniciar servidor MCP en puerto local
- `/mcp-server stop` — detener servidor
- `/mcp-server status` — ver estado y herramientas expuestas
- `/mcp-server config` — configurar herramientas y permisos

---

## Flujo

### Paso 1 — Generar configuración MCP

```json
{
  "name": "pm-workspace-savia",
  "version": "0.52.0",
  "transport": "stdio",
  "tools": [
    "sprint-status", "daily-generate", "risk-predict",
    "burndown", "backlog-health", "pbi-create"
  ],
  "permissions": {
    "read": true,
    "write": false,
    "execute_commands": ["sprint-*", "daily-*", "backlog-*"]
  }
}
```

### Paso 2 — Exponer herramientas seleccionadas

```
📡 MCP Server — pm-workspace-savia

  Estado: 🟢 Activo (stdio)
  Herramientas expuestas: {N}

  Read-only:
    ├─ sprint-status — estado actual del sprint
    ├─ burndown — datos de burndown chart
    ├─ backlog-health — salud del backlog
    └─ risk-predict — predicción de riesgo

  Read-write (requiere confirmación):
    ├─ pbi-create — crear PBI desde otro proyecto
    └─ daily-generate — generar daily report
```

### Paso 3 — Generar snippet de conexión

Para que otro proyecto Claude Code conecte:

```json
{
  "mcpServers": {
    "pm-workspace": {
      "command": "node",
      "args": ["path/to/pm-workspace/mcp-server.js"],
      "env": { "PM_PROJECT": "sala-reservas" }
    }
  }
}
```

### Paso 4 — Logs y monitorización

Registrar cada llamada: timestamp, tool, caller, resultado.

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: mcp_server
state: "running"
tools_exposed: 6
transport: "stdio"
read_only_tools: 4
read_write_tools: 2
```

---

## Restricciones

- **NUNCA** exponer datos sensibles (PATs, credenciales, perfiles privados)
- **NUNCA** permitir write sin confirmación explícita del usuario
- **NUNCA** exponer herramientas de administración (backup, profile-setup)
- Las herramientas write requieren aprobación por llamada
- Logs de acceso siempre activos — no se pueden desactivar
