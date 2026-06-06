---
name: _template
description: "TEMPLATE — copia este directorio para crear una skill nueva. NO se carga en runtime."
maturity: template
context: standalone
context_cost: low
category: "meta"
tags: ["template", "scaffold"]
priority: "low"
# SE-152: Semantic routing fields (optional — omit if not applicable)
# consumes:        # inputs que esta skill necesita para ejecutarse
#   - spec         # valores típicos: spec, pbi, project_slug, sprint_data,
#   - project_slug #   workspace_files, session_data, task, report, graph_db
# produces:        # artefactos que esta skill genera como output
#   - report       # valores típicos: spec, report, implementation, memory_entry,
#   - CONTEXT.md   #   graph_db, CONTEXT.md, pr, test_suite
---

<!--
  HOW TO USE THIS TEMPLATE
  ------------------------
  1. Copy `.claude/skills/_template/` to `.claude/skills/<your-skill-name>/`
  2. Replace ALL `<placeholder>` markers below.
  3. Update frontmatter `name`, `description`, `tags`.
  4. Delete this HOW TO block before commit.
  5. Skill must stay ≤150 lines (Rule #11).

  PATTERN: "Authoritative Paths First" (SE-153)
  ---------------------------------------------
  Inspirado en el patrón flowsint. La sección Authoritative Paths
  va PRIMERO, antes de cualquier prosa explicativa o tutorial.
  Razón: agentes leen top-down y se quedan sin contexto. Si los
  paths canónicos están al final, el agente los pierde y empieza
  a inventar firmas. Si están al principio, el agente sabe a
  dónde mirar antes de leer el resto de la skill.
-->

## Subagent Scope Guard

> Si fuiste invocado como subagente con una tarea concreta, ejecuta solo
> esa tarea y reporta DONE / DONE_WITH_CONCERNS / BLOCKED. NO actives el
> workflow completo de esta skill. (Borra esta sección si la skill no es
> orquestadora.)

# Skill: <Nombre Legible>

<Una frase. Qué problema resuelve.>

## Authoritative Paths

> **Lee estos paths antes de actuar. NUNCA asumas firmas, NUNCA inventes paths.**

| Para | Lee este path |
|---|---|
| <tipos / contratos / interfaces> | `<path/to/types.md>` |
| <handlers / entry points> | `<path/to/handlers/>` |
| <configuración / constantes> | `<path/to/config.md>` |
| <reglas de negocio aplicables> | `<path/to/rules/>` |
| <tests de referencia> | `<path/to/tests/>` |

**Reglas duras**:
- Si un path no existe, ABORTA y reporta — no inventes uno alternativo.
- Si una firma no está documentada en los paths, lee el código fuente directamente.
- Si la tarea requiere un path no listado aquí, primero añádelo a esta tabla.

## Cuándo usar

- <Trigger 1: situación concreta detectable>
- <Trigger 2>
- <Trigger 3>

## Cuándo NO usar

- <Anti-trigger 1: situación donde otra skill es más apropiada>
- <Anti-trigger 2>

## Decision Checklist

1. <Pregunta binaria 1> → si NO: <acción>
2. <Pregunta binaria 2> → si NO: <acción>
3. <Pregunta binaria 3> → si NO: <acción>

### Abort Conditions

- <Condición que invalida la skill — abortar y delegar>
- <Otra>

## Workflow

```
<paso 1: input>
    ↓
<paso 2: transformación>
    ↓
<paso 3: output / handoff>
```

### Detalle de cada paso

1. **<Paso 1>**: <qué hacer, qué leer, qué escribir>
2. **<Paso 2>**: <qué hacer, qué leer, qué escribir>
3. **<Paso 3>**: <qué hacer, qué leer, qué escribir>

## Outputs esperados

- <Fichero / commit / PR / mensaje>
- <Métrica observable>

## Memory hooks

- <Tipo de fact a guardar tras éxito> → `bash scripts/memory-store.sh save --type <type> --title "<title>" --content "<content>" --source skill:<name>`
- <Tipo de pattern a recall al inicio> → `bash scripts/memory-store.sh recall <topic>`

## Related

- Skill: `<../related-skill/SKILL.md>`
- Rule: `<docs/rules/domain/related-rule.md>`
- Spec: `<docs/propuestas/SPEC-XXX.md>`
- Roadmap: `<docs/ROADMAP.md#SE-XXX>`
