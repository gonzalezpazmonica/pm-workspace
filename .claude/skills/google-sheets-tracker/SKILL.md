---
name: google-sheets-tracker
description: Google Sheets Tracker
summary: |
  Sincroniza datos del workspace con Google Sheets.
  Genera y actualiza hojas con metricas, backlog, timesheets.
  Bidireccional: lee datos de Sheets como input.
maturity: beta
category: "reporting"
tags: ["google-sheets", "tracking", "metrics", "stakeholders"]
priority: "low"
---

# Google Sheets Tracker

**Nombre:** google-sheets-tracker

**Descripción:** Utiliza Google Sheets como base de datos ligera para seguimiento de tareas y métricas, permitiendo que POs y stakeholders trabajen sin acceso a Azure DevOps.

## Estructura de Hojas

La hoja de cálculo de seguimiento contiene 3 hojas principales:

### Hoja 1: Tasks (Tareas)
Columnas:
- **ID** — Identificador único de la tarea
- **Title** — Título descriptivo
- **Status** — Estado (To Do, In Progress, Done, Blocked)
- **Assignee** — Responsable asignado
- **Estimate** — Puntos estimados
- **Actual** — Puntos reales consumidos
- **Sprint** — Sprint al que pertenece
- **PBI-ref** — Referencia al PBI en Azure DevOps

### Hoja 2: Metrics (Métricas)
Columnas:
- **Sprint** — Identificador del sprint
- **Velocity** — Velocidad acumulada de puntos
- **Burndown** — Progreso del burndown (% completado)
- **Blockers** — Número de tareas bloqueadas
- **Completion%** — Porcentaje de completitud del sprint

### Hoja 3: Risks (Riesgos)
Columnas:
- **ID** — Identificador del riesgo
- **Description** — Descripción del riesgo identificado
- **Score** — Puntuación de impacto (1-5)
- **Mitigation** — Plan de mitigación
- **Owner** — Responsable del seguimiento
- **Status** — Estado (Active, Mitigated, Closed)

## Funcionalidades

### Sincronización Bidireccional
- Las tareas se sincronizan automáticamente con Azure DevOps
- Las actualizaciones de estado en Sheets se propagan a Azure DevOps
- Cambios en Azure DevOps se reflejan en Sheets

### Lectura para POs
- Los Product Owners pueden visualizar y filtrar tareas sin acceso a Azure DevOps
- Vista de métricas en tiempo real
- Tracking de riesgos e impedimentos

### Escritura desde Sheets
- Actualizaciones de estado se sincronizan bidireccionalamente
- Las estimaciones pueden ajustarse en Sheets
- Cambios en el estado de riesgos se propagan automáticamente

## Integración MCP

Utiliza el servidor MCP `google-sheets` para:
- Lectura y escritura de celdas
- Formateo y validación de datos
- Gestión de permisos y compartición
- Notificaciones de cambios

## Casos de Uso

1. **Seguimiento Visual** — POs visualizan el progreso del sprint sin herramientas técnicas
2. **Métricas Ágiles** — Burndown, velocity y completion% actualizados automáticamente
3. **Gestión de Riesgos** — Seguimiento centralizado de impedimentos y riesgos
4. **Reportes** — Datos listos para análisis y presentaciones
5. **Colaboración** — Acceso compartido a stakeholders sin permisos de Azure DevOps
