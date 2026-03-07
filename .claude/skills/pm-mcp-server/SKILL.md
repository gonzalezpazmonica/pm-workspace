# PM-Workspace MCP Server

**Nombre:** pm-mcp-server

**Descripción:** Expone el estado de PM-Workspace como servidor MCP para consumo de herramientas externas, permitiendo que clientes remotos accedan a la gestión de proyectos sin interfaz directa.

## Recursos Expuestos

1. **project-list** — Lista de proyectos activos con estado, propietario y métricas
2. **pbi-details** — Detalles de Product Backlog Items: descripción, criterios de aceptación, estado
3. **task-status** — Estado actual de tareas: asignado, en progreso, completado, bloqueado
4. **team-capacity** — Capacidad del equipo: disponibilidad, carga actual, velocidad
5. **sprint-metrics** — Métricas de sprint: burn-down, completitud, velocidad, tendencias
6. **risk-register** — Registro de riesgos: identificación, impacto, mitigación, estado

## Herramientas Expuestas

1. **create-pbi** — Crear nuevo Product Backlog Item con descripción y criterios
2. **update-task-status** — Actualizar estado de tarea (asignado, en progreso, completado)
3. **assign-task** — Asignar tarea a miembro del equipo
4. **generate-report** — Generar reportes: sprint, proyecto, equipo, riesgos

## Prompts Expuestos

1. **sprint-planning** — Asistencia para planificación de sprint con recomendaciones
2. **pbi-decomposition** — Descomposición de PBI en tareas técnicas
3. **risk-assessment** — Evaluación de riesgos y estrategias de mitigación

## Transporte

- **Modo Local (stdio)** — Comunicación directa sin red, máxima seguridad
- **Modo Remoto (SSE)** — Server-Sent Events sobre HTTP, acceso remoto seguro

## Configuración

Archivo: `.claude/mcp-server-config.json`

```json
{
  "transport": "stdio|sse",
  "port": 3000,
  "resources": ["project-list", "pbi-details", "task-status", "team-capacity", "sprint-metrics", "risk-register"],
  "tools": ["create-pbi", "update-task-status", "assign-task", "generate-report"],
  "prompts": ["sprint-planning", "pbi-decomposition", "risk-assessment"],
  "auth": {"type": "token|none", "tokenRequired": true},
  "readOnly": false
}
```

## Autenticación

- **Local (stdio)** — Sin autenticación
- **Remoto (SSE)** — Token Bearer obligatorio
- **Modo Solo Lectura** — Disponible para ambos transportes, desactiva herramientas de escritura

## Casos de Uso

- Integración con herramientas de IA externas
- Dashboards de terceros consumiendo métricas
- Automatización de flujos de trabajo PM
- Reportería personalizada desde sistemas externos

## Estado

✓ Implementado en Release 21 — 2026-03-07
