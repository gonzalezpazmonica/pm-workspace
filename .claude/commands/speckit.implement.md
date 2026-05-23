---
name: /speckit.implement
description: "Alias spec-kit compatible. Implementación supervisada de una spec aprobada. Invoca dev-orchestrator. Compatible con github/spec-kit."
developer_type: all
agent: task
context_cost: high
---

# /speckit.implement — Implementación

> **Alias compatible con `github/spec-kit`**. Equivalente Savia: agente `dev-orchestrator` + flujo SDD multi-agente.

## Qué hace

Orquesta la implementación de una spec APPROVED: crea ramas, asigna agentes por lenguaje, genera PRs Draft slice-by-slice. **Siempre Draft, siempre revisión humana** (autonomous-safety Rule #10).

## Sintaxis

```
/speckit.implement [spec_id | ruta-a-spec]
```

## Ejecución

1. Verifica que la spec esté APPROVED (Code Review E1 humano completado).
2. Carga agente `dev-orchestrator`.
3. Descompone en slices con presupuesto de contexto.
4. Asigna agentes por lenguaje (dotnet-developer, python-developer, etc).
5. Genera PRs Draft por slice con AUTONOMOUS_REVIEWER asignado.

## Equivalencias

Ver `docs/agent-teams-sdd.md`.
