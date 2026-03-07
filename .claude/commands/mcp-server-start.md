# Comando: /mcp-server-start

**Descripción:** Inicia el servidor MCP para exponer PM-Workspace a herramientas externas.

## Uso

```
/mcp-server-start {mode} [--read-only]
```

## Parámetros

- **mode** — `local` (stdio, comunicación directa) o `remote` (SSE, servidor HTTP)
- **--read-only** (opcional) — Desactiva herramientas de escritura, solo exposición de recursos

## Resultados

Al iniciar correctamente, muestra:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ MCP Server iniciado — Modo {mode}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📍 Endpoint: {local:stdio | remote:http://localhost:3000}
🔐 Autenticación: {none (local) | Bearer token (remote)}

Recursos disponibles (6):
  - project-list
  - pbi-details
  - task-status
  - team-capacity
  - sprint-metrics
  - risk-register

Herramientas disponibles (4):
  - create-pbi
  - update-task-status
  - assign-task
  - generate-report

Prompts disponibles (3):
  - sprint-planning
  - pbi-decomposition
  - risk-assessment

💾 Configuración: .claude/mcp-server-config.json
⏱️  Hora: YYYYMMDD HH:mm:ss UTC
```

## Modo local (stdio)

Comunicación directa sin servidor HTTP. La herramienta cliente se conecta vía pipe o fichero de configuración MCP.

## Modo remoto (SSE)

Expone servidor HTTP en puerto 3000 (configurable). Requiere token Bearer para autenticación.

Token debe incluirse en header:
```
Authorization: Bearer {TOKEN}
```

## Parada

```
/mcp-server-stop
```

Detiene el servidor limpiamente.

## Estado

```
/mcp-server-status
```

Muestra: endpoint, conexiones activas, requests procesados, uptime.
