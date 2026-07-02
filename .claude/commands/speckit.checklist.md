---
name: /speckit.checklist
description: "Alias spec-kit compatible. Gate de calidad final con verification-lattice multi-capa. Invoca skill verification-lattice. Compatible con github/spec-kit."
developer_type: all
agent: task
context_cost: high
tier: core
---

# /speckit.checklist — Gate de calidad final

> **Alias compatible con `github/spec-kit`**. Equivalente Savia: skill `verification-lattice`.

## Qué hace

Verificación multi-capa post-implementación: tests, cobertura, mutation testing, performance, security, accessibility, docs.

## Sintaxis

```
/speckit.checklist [spec_id | ruta-a-spec]
```

## Ejecución

1. Carga skill `verification-lattice`.
2. Ejecuta capas en orden: tests → coverage → mutation → perf → security → a11y → docs.
3. Cada capa fail → bloquea merge y delega a agente correspondiente.
4. Output: `output/checklist-{spec_id}-{date}.md` con resultados por capa.

## Equivalencias

Ver `docs/agent-teams-sdd.md`.
