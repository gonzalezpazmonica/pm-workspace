---
context_tier: L3
token_budget: 850
audience: all-agents
---

# Regla: Context Origin Tagging — Trazabilidad de fragmentos cargados

> **REGLA APLICATIVA** — Aplica a outputs de Read que superan umbral de lineas.
> Spec: SE-221 (Slice 1). Fecha: 2026-06-12

## Principio

Cada fragmento cargado en el contexto que supere CONTEXT_ORIGIN_MIN_LINES
(default 200 lineas) lleva un bloque YAML al inicio que indica path, tier
N1..N5, timestamp, tamano estimado en tokens y hash sha256 corto.

El proposito es doble: trazabilidad cuando un fichero se mueve entre niveles
N1-N4b, y auditoria post-mortem de que ficheros entraron al contexto.

## Cuando se aplica

- PostToolUse Read: el hook context-origin-stamp.sh prefija el output con el
  bloque cuando supera el umbral.
- Sandbox: exento (work-in-progress, no contexto).
- Outputs bajo umbral: passthrough.
- Idempotencia: si el output ya empieza por marca origin, no se duplica.

## Tiers canonicos

Ver mapeo completo en scripts/context-origin-tag.sh:

- N1-anchor: anchor superior, hechos invariantes
- N2-eager: carga critica eager
- N3-active-user: perfiles + memoria del usuario activo
- N4a-lazy-ref: tabla de referencias lazy
- N4b-on-demand: rules/skills/agents bajo demanda
- N4-project: datos de proyecto
- N5-external: fuera del workspace, en HOME
- untrusted: fuera de workspace y de HOME
- sandbox: workspace efimero del agente

## Override

- Variable CONTEXT_ORIGIN_MIN_LINES ajusta el umbral (default 200).
- Para deshabilitar el hook en una sesion concreta: NO esta soportado por
  diseno. Si el output es problematico, ajustar el umbral.

## Verificacion

Tests de cobertura:
- bats tests/test-context-origin-tag.bats
- bats tests/test-context-origin-stamp-hook.bats

## Refs

- SE-221 spec en docs/propuestas/
- docs/rules/domain/context-placement-confirmation.md
- Hines et al. 2024, "Spotlighting" arXiv:2403.14720
