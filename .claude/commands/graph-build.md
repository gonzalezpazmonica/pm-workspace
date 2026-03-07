---
name: graph-build
description: Construye el grafo de conocimiento PM para un proyecto
allowed-tools:
  - Read
  - Write
  - Glob
  - Bash
  - Task
context_cost: medium
---

# /graph-build {project}

Escanea todas las fuentes PM (Azure DevOps, equipo.md, reglas-negocio.md, agent-notes) y construye un grafo JSONL con 8 tipos de entidades y 7 tipos de relaciones.

## Prerequisitos

1. Proyecto existe: `projects/{project}/CLAUDE.md`
2. Equipo documentado: `projects/{project}/equipo.md`
3. Reglas de negocio: `projects/{project}/reglas-negocio.md` (opcional)
4. Azure DevOps configurado (PAT válido)

## Ejecución

1. 🏁 Banner: `══ /graph-build {project} ══`
2. **Fase 1 — Recopilar entidades**
   - Leer Azure DevOps: PBIs, Tasks, Members, Sprints
   - Leer equipo.md: Members, Skills
   - Leer reglas-negocio.md: Decisions, Risks
   - Leer agent-notes/: contexto de riesgos, decisiones
3. **Fase 2 — Construir relaciones**
   - Project HAS_PBI (work items por proyecto)
   - PBI DECOMPOSES_TO Task (jerarquía)
   - Task ASSIGNED_TO Member (asignaciones)
   - Member HAS_SKILL Skill (capabilities)
   - Task HAS_RISK Risk (riesgos de tarea)
   - Decision AFFECTS Task (impacto decisiones)
   - Sprint CONTAINS Task (tareas del sprint)
4. **Fase 3 — Guardar grafo**
   - Escribir JSONL: `data/knowledge-graph/{project}.jsonl`
   - Una entidad/relación por línea
   - Crear índice: `data/knowledge-graph/.index`
5. ✅ Banner fin: `{N} entidades, {M} relaciones`

## Output

`data/knowledge-graph/{project}.jsonl` — grafo serializado
`data/knowledge-graph/.index` — índice de proyectos (lista de grafos disponibles)

## Reglas

- Idempotente: ejecutar 2 veces produce mismo resultado
- Reemplaza grafo anterior (backup automático)
- Máximo 60 líneas
