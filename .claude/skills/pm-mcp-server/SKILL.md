---
name: pm-mcp-server
description: PM-Workspace MCP Server
maturity: alpha
category: "devops"
tags: ["mcp", "server", "api", "integration"]
priority: "low"
---

# PM-Workspace MCP Server

**Nombre:** pm-mcp-server

**Descripción:** Expone el estado de PM-Workspace como servidor MCP para consumo de herramientas externas.

## Recursos Expuestos

1. **project-list** — Lista de proyectos activos con estado, propietario y métricas
2. **pbi-details** — Detalles de Product Backlog Items
3. **task-status** — Estado actual de tareas
4. **team-capacity** — Capacidad del equipo: disponibilidad, carga actual, velocidad
5. **sprint-metrics** — Métricas de sprint: burn-down, completitud, velocidad
6. **risk-register** — Registro de riesgos: identificación, impacto, mitigación, estado

## Herramientas Expuestas

1. **create-pbi** — Crear nuevo Product Backlog Item
2. **update-task-status** — Actualizar estado de tarea
3. **assign-task** — Asignar tarea a miembro del equipo
4. **generate-report** — Generar reportes

## Prompts Expuestos

1. **sprint-planning** — Asistencia para planificación de sprint
2. **pbi-decomposition** — Descomposición de PBI en tareas técnicas
3. **risk-assessment** — Evaluación de riesgos y estrategias de mitigación

## Transporte

- **Modo Local (stdio)** — Comunicación directa sin red
- **Modo Remoto (SSE)** — Server-Sent Events sobre HTTP

## Configuración

Archivo: `.claude/mcp-server-config.json`

## Autenticación

- **Local (stdio)** — Sin autenticación
- **Remoto (SSE)** — Token Bearer obligatorio
- **Modo Solo Lectura** — Desactiva herramientas de escritura

## Estado

✓ Implementado en Release 21 — 2026-03-07
