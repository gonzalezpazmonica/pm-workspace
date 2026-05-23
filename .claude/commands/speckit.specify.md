---
name: /speckit.specify
description: "Alias spec-kit compatible. Captura el what inicial de una spec (JTBD + PRD). Invoca skill product-discovery de Savia. Compatible con github/spec-kit."
developer_type: all
agent: task
context_cost: medium
---

# /speckit.specify — Captura inicial de spec

> **Alias compatible con `github/spec-kit`**. Equivalente Savia: skill `product-discovery`.

## Qué hace

Captura el "what" inicial de una feature/PBI usando JTBD (Jobs To Be Done) + PRD light antes de descomponer en tasks. Output: borrador de spec en `output/specs/draft-{slug}-{date}.md`.

## Sintaxis

```
/speckit.specify [descripción del feature]
```

`$ARGUMENTS` se propaga como brief. Vacío → entrevista interactiva.

## Ejecución

1. Carga skill `product-discovery`.
2. Si `$ARGUMENTS` presente → lo usa como brief inicial.
3. Si vacío → entrevista interactiva guiada (JTBD primero, luego PRD).
4. Output: borrador en `output/specs/draft-{slug}-{date}.md`.

## Equivalencias

Ver `docs/agent-teams-sdd.md` — tabla "spec-kit ↔ Savia".
