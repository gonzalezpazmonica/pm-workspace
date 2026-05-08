---
id: SPEC-074
title: SPEC-074: Parallel Doc QA — Digestión Paralela de Múltiples Documentos
status: PROPOSED
origin_date: "2026-03-25"
migrated_at: "2026-04-19"
migrated_from: body-prose
priority: media
---

# SPEC-074: Parallel Doc QA — Digestión Paralela de Múltiples Documentos

> Status: **DRAFT** · Fecha: 2026-03-25 · Score: 3.60
> Origen: Qwen-Agent pattern "ParallelDocQA"
> Impacto: meeting-digest N documentos ~N veces más rápido

---

## Problema

`meeting-digest` procesa documentos secuencialmente. Con 5 reuniones
para digerir, el tiempo es 5× el de una sola reunión. El contexto del
agente también se acumula entre documentos, degradando la calidad.

Qwen-Agent resuelve con ParallelDocQA: cada documento va a un subagente
con contexto fresco, los resultados se agregan al final.

## Solución

Añadir flag `--parallel` a `/meeting-digest`:

```
/meeting-digest --folder reuniones/sprint-12/ --parallel
  → Detecta N documentos
  → Lanza N subagentes Task en paralelo (límite: SDD_MAX_PARALLEL_AGENTS=5)
  → Cada subagente digiere 1 documento con contexto fresco
  → Agrega resultados: action items unificados, decisiones deduplicadas
  → Output: digest consolidado en output/meetings/
```

## Implementación

En `.opencode/commands/meeting-digest.md`:

```markdown
Si --parallel y N > 1:
  1. Dividir lista de ficheros en batches de ≤5
  2. Para cada batch: Task paralelas con meeting-digest agent
  3. Cada Task devuelve JSON: {actions, decisions, risks, participants}
  4. Agregar: deduplicar por similaridad, ordenar por prioridad
  5. Escribir digest consolidado
```

Agente ya existe: `meeting-digest` en catálogo (Sonnet 4.6).

## Degradación

Sin `--parallel` → comportamiento actual (secuencial, sin cambios).
Con 1 documento → ignorar `--parallel`, procesar normalmente.
Si un subagente falla → incluir en digest con nota "digestión fallida: {fichero}".

## Tests

- 3 documentos en paralelo < 3× tiempo secuencial
- Deduplicación: misma decisión mencionada en 2 docs → aparece 1 vez en output
- Fallo de un subagente no cancela el resto
- Output consolidado tiene secciones: Decisiones, Action Items, Riesgos
