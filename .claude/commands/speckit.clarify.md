---
name: /speckit.clarify
description: "Alias spec-kit compatible. Preguntas dirigidas para cerrar ambigüedad en una spec. Invoca skill context-interview-conductor. Compatible con github/spec-kit."
developer_type: all
agent: task
context_cost: medium
tier: core
---

# /speckit.clarify — Cerrar ambigüedad

> **Alias compatible con `github/spec-kit`**. Equivalente Savia: skill `context-interview-conductor`.

## Qué hace

Hace preguntas dirigidas sobre una spec existente para cerrar ambigüedades antes de pasar a `/speckit.plan`. Detecta supuestos no declarados, casos límite no cubiertos, dependencias implícitas.

## Sintaxis

```
/speckit.clarify [ruta-a-spec | spec_id]
```

`$ARGUMENTS` = path o ID de spec.

## Ejecución

1. Carga skill `context-interview-conductor`.
2. Lee la spec target.
3. Genera 5-15 preguntas dirigidas según huecos detectados.
4. Output: bloque "Aclaraciones" anexado a la spec.

## Equivalencias

Ver `docs/agent-teams-sdd.md`.
