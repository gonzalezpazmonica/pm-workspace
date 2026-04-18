---
id: SE-034
title: Workflow node typing — input/output schemas explicitos en DAG skills
status: PROPOSED
origin: Dify research 2026-04-18 (api/core/workflow node types)
author: Savia
related: dag-plan, dag-execute, dag-scheduling, wave-executor, spec-slice
approved_at: null
applied_at: null
expires: "2026-05-16"
---

# SE-034 — Workflow node typing

## Purpose

Si NO hacemos esto: nuestro DAG de skills es duck-typed — un skill declara `input: X` en frontmatter pero nadie valida que el upstream produzca X. Errores en runtime, no en planning. `dag-plan` puede mostrar un grafo que en ejecucion falla porque skill A devolvio JSON pero skill B esperaba markdown.

Cost of inaction: debugging de pipelines DAG rotos consume tiempo desproporcionado. Hoy depende de que el humano revise mentalmente el contrato entre skills. No escala con 77 skills + nuevos.

## Objective

Extender frontmatter de skills con schema explicito I/O (JSON Schema subset) y hacer que `dag-plan` valide el grafo **antes** de ejecutar, fallando si hay mismatch de tipos. Criterio: detectar 100% de mismatches conocidos en 10 DAGs de referencia antes de runtime.

## Slicing

- Slice 1: definicion del schema subset + migrar 5 skills piloto con I/O typing
- Slice 2: validador en `dag-plan` que cruza upstream/downstream
- Slice 3: migracion opt-in de skills restantes con backwards-compat (no schema = duck-typed)

## Referencias

- Dify workflow nodes: https://github.com/langgenius/dify/tree/main/api/core/workflow
- JSON Schema: https://json-schema.org/

## Dependencia

Independiente de SE-032/SE-033. Prioridad medio-bajo (no hay dolor agudo hoy, pero escala mal).
