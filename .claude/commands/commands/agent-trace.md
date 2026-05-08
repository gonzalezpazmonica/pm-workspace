---
name: agent-trace
description: Dashboard de trazas de ejecución de agentes con tokens, duración y resultado
developer_type: agent-single
agent: azure-devops-operator
context_cost: low
---

# Comando: agent-trace

## Descripción

Muestra un dashboard interactivo de las trazas de ejecución de agentes para el proyecto activo. Cada traza registra información de tokens, duración, ficheros modificados y resultado de la ejecución.

## Datos

Lectura desde `projects/{proyecto}/traces/agent-traces.jsonl` (formato JSONL).
Cada línea contiene: `{ timestamp, agent, command, tokens_in, tokens_out, duration_ms, files_modified: [], outcome: "success"|"failure"|"partial", scope_violations: [] }`

## Comportamiento

**Por defecto:** Muestra últimas 20 trazas del proyecto activo

**Filtros:**
- `--agent {nombre}` — filtrar por nombre de agente
- `--last {N}` — mostrar últimas N trazas
- `--failures-only` — mostrar solo ejecuciones fallidas

## Output

Tabla con columnas:
- **Timestamp** — fecha y hora de ejecución
- **Agent** — nombre del agente que ejecutó
- **Command** — comando/tarea ejecutada
- **Tokens** — tokens_in / tokens_out (ej: 2500/5100)
- **Duration** — duración en ms
- **Files** — número de ficheros modificados
- **Outcome** — success / failure / partial

Fila de resumen: total tokens, duración promedio, tasa de éxito

### Estilos visuales
- Fallos en rojo, scope violations como advertencias
- Si no hay trazas: explicar cómo habilitar (session-init hook genera trazas)

## Ejemplos

```
/agent-trace
/agent-trace --agent dotnet-developer
/agent-trace --last 5 --failures-only
```

## Requisitos

- Fichero de trazas debe existir en `projects/{proyecto}/traces/`
- Formato JSONL válido
- Proyecto activo definido via `/context-load`
