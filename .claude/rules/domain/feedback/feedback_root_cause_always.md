---
type: feedback
slug: root_cause_always
source: SPEC-188 Fase 0 (cierre hallazgo G3)
created: 2026-06-04
verified_source: docs/propuestas/SPEC-188-root-cause-investigation-architecture.md
related:
  - SPEC-043
  - SPEC-065
  - SPEC-108
  - SPEC-125
  - SE-072
  - docs/rules/domain/verified-memory-axiom.md
status: active
context_tier: L2
token_budget: 800
spec: SPEC-188
phase: 0
---

# feedback_root_cause_always

Memoria canonica de feedback. Referenciada por memory-conflict-judge
(Recommendation Tribunal), responsibility-judge (SPEC-043) y
execution-supervisor (SPEC-065).

Creada en SPEC-188 Fase 0 para cerrar el hallazgo G3.

## Regla canonica

NEVER propose shortcuts (lower thresholds, skip tests, retry without
investigation, hook-skip flags, mark tests as expected-failure). ALWAYS
investigate the root cause first.

## Patrones prohibidos

1. Bajar umbral para que pase CI sin explicacion causal documentada.
2. Marcar test como skip/xfail/pending sin issue tracked y root cause.
3. Re-intentar la misma operacion 3 o mas veces con variantes superficiales.
4. Usar --no-verify en commits o push sin incidente declarado.
5. Comentar o eliminar assertion en test para que pase.
6. Solo por esta vez seguido de un atajo no documentado.
7. Cambiar threshold de scoring sin spec ni justificacion causal.
8. Bajar criterios de aceptacion porque la implementacion no llega.
9. Marcar SPEC como IMPLEMENTED cuando los AC no se cumplen integramente.
10. Re-ejecutar tests a ver si esta vez pasan sin cambio causal.

## Que SI esta permitido con justificacion documentada

- Bajar threshold si la spec lo aprueba con Causal-Evidence poblado.
- Skip temporal con issue abierto, ETA y root cause documentada.
- Bypass de hook si hay incidente operativo declarado con [hotfix] trailer.

## Por que importa

Cada atajo instala el patron. Tres meses despues, los tests no
garantizan nada porque sus thresholds han bajado todos.

## Consumidores

- memory-conflict-judge (Recommendation Tribunal, SPEC-125): veto si viola estos patrones.
- responsibility-judge (SPEC-043 cuando implementado): bloquea PreToolUse shortcut patterns.
- execution-supervisor (SPEC-065 cuando implementado): exhibe esta memoria tras attempt 3.

## Cambios

- 2026-06-04: creacion (SPEC-188 Fase 0, cierre G3).
