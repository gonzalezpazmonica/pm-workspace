---
name: /speckit.analyze
description: "Alias spec-kit compatible. Review cruzado de una spec antes de implementar. Invoca skill consensus-validation. Compatible con github/spec-kit."
developer_type: all
agent: task
context_cost: high
tier: core
---

# /speckit.analyze — Review cruzado

> **Alias compatible con `github/spec-kit`**. Equivalente Savia: skill `consensus-validation`.

## Qué hace

Ejecuta review cruzado con panel de 4 jueces (reflection, code-review, business, performance) sobre una spec antes de aprobar para implementación.

## Sintaxis

```
/speckit.analyze [spec_id | ruta-a-spec]
```

## Ejecución

1. Carga skill `consensus-validation`.
2. Convoca panel de 4 jueces en paralelo.
3. Agrega scores y aplica vetos.
4. Output: veredicto APPROVED / NEEDS_FIXES / BLOCKED.

## Equivalencias

Ver `docs/agent-teams-sdd.md`.
