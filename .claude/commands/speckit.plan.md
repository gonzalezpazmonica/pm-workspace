---
name: /speckit.plan
description: "Alias spec-kit compatible. Diseño técnico de una spec ya capturada. Invoca skill spec-driven-development sección Plan. Compatible con github/spec-kit."
developer_type: all
agent: task
context_cost: high
---

# /speckit.plan — Plan técnico

> **Alias compatible con `github/spec-kit`**. Equivalente Savia: skill `spec-driven-development` (sección Plan).

## Qué hace

Genera el diseño técnico de una spec: arquitectura, módulos afectados, contratos, dependencias, riesgos.

## Sintaxis

```
/speckit.plan [spec_id | ruta-a-spec]
```

## Ejecución

1. Carga skill `spec-driven-development`.
2. Lee spec capturada en `/speckit.specify`.
3. Genera secciones Design / Acceptance Criteria / Slicing / Riesgos.
4. Output: spec ampliada con plan técnico.

## Equivalencias

Ver `docs/agent-teams-sdd.md`.
