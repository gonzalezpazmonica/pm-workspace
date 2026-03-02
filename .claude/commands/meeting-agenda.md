---
name: meeting-agenda
description: Generación inteligente de agendas basada en estado del sprint y temas pendientes
agent: none
context_cost: low
---

# /meeting-agenda

> 🦉 Agenda inteligente: analiza sprint, detecta topics pendientes, sugiere estructura con tiempos.

---

## Parámetros

- `--project {nombre}` — Proyecto (obligatorio)
- `--type {planning|review|retro|refinement|standup|custom}` — Tipo reunión (defecto: custom)
- `--sprint {nombre}` — Sprint específico (defecto: actual)
- `--attendees {n}` — Nº asistentes para ajustar timebox
- `--duration {min}` — Duración total (defecto: 60 min)
- `--context-files {ficheros}` — Ficheros adicionales (ej: decision-log.md)
- `--dry-run` — Mostrar sin guardar

---

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config proyecto
2. `projects/{proyecto}/sprint-YYYY-NN.md` — Estado sprint actual
3. `projects/{proyecto}/team.md` — Equipo
4. Opcionales: risk-register.md, retro-actions.md, decision-log.md

---

## Ejecución

### 1. Analizar contexto sprint
- Burndown: % completado, velocity real vs proyectada
- Work items: activos, bloqueados, en review, completados
- Riesgos: qué está en rojo
- Deuda técnica: nueva desde último sprint

### 2. Detectar topics pendientes
- Bloqueantes sin resolver
- Decisiones sin aprobación
- PBIs sin criterios claros
- Riesgos sin estrategia
- Retro actions rezagadas

### 3. Generar items por tipo

**PLANNING**: sprint goal (5m) | refined backlog (20m) | capacity (5m) | risks (5m) | Q&A (5m)

**REVIEW**: recap goal (2m) | demos (30m) | metrics (5m) | forecast (5m) | Q&A (8m)

**RETRO**: recap anterior (3m) | went well (10m) | improvements (10m) | blockers (8m) | actions (5m) | closing (4m)

**REFINEMENT**: backlog overview (5m) | top 10 PBIs (40m) | tech concerns (10m) | roadmap (5m)

**CUSTOM**: items basados en bloqueantes, riesgos, decisiones pendientes

### 4. Asignar timebox y sugerir asistentes

Calcula % de tiempo por topic según prioridad/urgencia. Sugiere asistentes según topics.

### 5. Generar markdown

Salida en `output/agendas/YYYYMMDD-{tipo}-{proyecto}.md`:
- Objetivo reunión
- Orden del día con timebox
- Decisiones pending (requiere acción hoy)
- Pre/post-meeting checklist
- Contexto cargado

---

## Integración

- `/sprint-plan` → `/meeting-agenda --type planning --sprint {nuevo}`
- `/sprint-review` → `/meeting-agenda --type review --sprint {actual}`
- `/sprint-retro` → `/meeting-agenda --type retro --sprint {actual}`

---

## Restricciones

- Read-only: NUNCA crear items automáticamente
- Sugerencias basadas en datos
- Si sin riesgos registrados: usar estado sprint como proxy
