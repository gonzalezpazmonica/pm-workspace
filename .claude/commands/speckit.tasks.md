---
name: /speckit.tasks
description: "Alias spec-kit compatible. Descomposición de spec en tasks accionables. Invoca skill pbi-decomposition. Compatible con github/spec-kit."
developer_type: all
agent: task
context_cost: medium
tier: core
---

# /speckit.tasks — Descomposición en tasks

> **Alias compatible con `github/spec-kit`**. Equivalente Savia: skill `pbi-decomposition`.

## Qué hace

Descompone una spec planificada en Tasks accionables con estimaciones en horas y asignación inteligente.

## Sintaxis

```
/speckit.tasks [spec_id | ruta-a-spec]
```

## Ejecución

1. Carga skill `pbi-decomposition`.
2. Lee spec con plan técnico ya generado.
3. Genera Tasks ≤8h cada una con criterio de aceptación atómico.
4. Output: lista de Tasks lista para crear en Azure DevOps / GitHub Issues.

## Equivalencias

Ver `docs/agent-teams-sdd.md`.
