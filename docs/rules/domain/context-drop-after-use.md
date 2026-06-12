---
context_tier: L3
token_budget: 600
audience: all-agents
---

# Regla: Context Drop-After-Use

> Spec: SE-221 Slice 2. Fecha: 2026-06-12.
> Compactacion automatica de outputs grandes que dejan de ser relevantes.

## Principio

Tras una operacion Read/WebFetch/Bash cuyo output supera el umbral
(CONTEXT_DROP_MIN_LINES, default 500), el hook decide entre tres veredictos:

- KEEP: contenido intacto.
- STUB: reemplazado por etiqueta con origin, tier, abstract.
- DROP: reemplazado por marcador minimo.

Objetivo: atacar el context bloat de ficheros leidos puntualmente que
persisten innecesariamente.

## Heuristica resumida

Ver scripts/context-drop-after-use.sh para la heuristica completa. Resumen:

- Override textual: si el siguiente turno contiene la marca KEEP-CONTEXT,
  fuerza KEEP siempre.
- Tier alto (anchor o eager): KEEP.
- Tier untrusted: DROP.
- Sandbox: KEEP.
- Referencia textual al basename o path en next-task: KEEP.
- Resto: STUB con abstract de una linea.

## Audit log

Cada decision se loggea como JSONL en output/context-drop-audit.jsonl con
campos basicos (ts, tool, path, tier, veredicto, ahorro estimado).

## Metrics CLI

  bash scripts/context-drop-metrics.sh
  bash scripts/context-drop-metrics.sh --json

## Verificacion

  bats tests/test-context-drop-after-use.bats

## Refs

- Spec SE-221 en docs/propuestas/
- Beurer-Kellner et al. 2025, Context-Minimization (arXiv:2506.08837)
