---
name: cache-warm
description: Pre-calentar caché con contexto probable basado en hora y rol
developer_type: all
agent: none
context_cost: high
---

# /cache-warm

> 🦉 Savia pre-calienta el caché de forma predictiva — por hora, por rol, por sprint.

---

## Cargar perfil de usuario

Grupo: **Context Engineering** — cargar:

- `identity.md` — rol del usuario
- `workflow.md` — hora de actividad, eventos del sprint

Ver `docs/rules/domain/context-map.md`.

---

## Parámetros

```
--role              Pre-calentar contexto del rol actual
--time auto|HH:MM   Asumir hora (auto = ahora, o especificar hora)
--lang es|en        Idioma del output
```

---

## Flujo

### Paso 1 — Detectar hora y rol

1. Leer hora actual o parámetro `--time`
2. Leer rol de `identity.md` (PM, Tech Lead, Developer, QA, etc.)
3. Leer `workflow.md` para saber si hay eventos hoy (sprint-planning, retro, etc.)

### Paso 2 — Mapear contexto probable por hora

**Morning (08:00-10:30)**
- Daily standup context → sprint status, team workload
- Load: `workflow.md` (rutina diaria), team status

**Late Morning (10:30-12:00)**
- Focus time → project context
- Load: proyecto activo, specs, decisions

**Afternoon (13:00-15:00)**
- Refinement/grooming
- Load: backlog, reglas negocio, estimación

**End of Day (15:00-17:00)**
- Reporting → DORA, KPIs
- Load: histórico sprints, métricas

**Friday PM (16:00-18:00)**
- Sprint review + retro
- Load: sprint items, decision-log, retrospective patterns

### Paso 3 — Mapear contexto por rol

**PM/Scrum Master**
- Always: workflow.md, sprint status, team capacity
- If daily: standup context
- If friday: review + retro context
- If wednesday: backlog grooming context

**Tech Lead**
- Always: tech-radar, team skills matrix
- If code-focused day: PR reviews, specs, architecture
- If friday: incident postmortems

**Developer**
- Always: my-sprint, my-focus (current task)
- If morning: standup, task context
- If afternoon: refocus on task, code patterns

**QA Engineer**
- Always: qa-dashboard
- If pre-release: test plans, bug triage
- If regression day: test cases, known issues

### Paso 4 — Ejecutar warm-up

1. Identificar ficheros a cargar (máx 5 fragmentos)
2. Cargar fragmentos en caché (sin mostrar contenido)
3. Registrar warm-up en context-tracking
4. Mostrar banner:

```
🔥 Cache Warmed — Contexto Precargado

Rol: Tech Lead
Hora: 10:45
Contexto cargado:
  ✅ workflow.md (80 tokens)
  ✅ tech-radar context (120 tokens)
  ✅ current-sprint state (90 tokens)

Total: 290 tokens precargados
Estimado hit rate: +35% en próximos comandos
```

### Paso 5 — Activar warm-up automático

Opcional: si el usuario lo pide, registrar en `.pm-workspace/warm-up-config`:
- Hora de ejecución automática (ej: 09:00 diarios)
- Patrones por día semana (diferentes para lunes vs. viernes)

---

## Validación

- ✅ Rol identificado correctamente
- ✅ Hora dentro de rango válido
- ✅ No más de 5 fragmentos cargados
- ✅ Caché no saturado antes de warm-up

