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
---

# feedback_root_cause_always

Memoria canonica de feedback. Referenciada por `memory-conflict-judge`
(Recommendation Tribunal) y por `verified-memory-axiom.md`. Creada en
SPEC-188 Fase 0 para cerrar el hallazgo G3: el sistema referenciaba
esta memoria como si existiera, pero el fichero no estaba en ningun
path. Ahora si esta.

## Regla canonica

NEVER propose shortcuts (lower thresholds, skip tests, retry without
investigation, hook-skip flags, mark tests as expected-failure). ALWAYS
investigate the root cause first.

## Patrones prohibidos

Estos patrones, si aparecen en una recomendacion o en un diff de
agente, son violaciones directas de esta memoria:

1. Bajar umbral para que pase CI: parametro reducido sin explicacion
   causal. Si el test falla con score real, hay que entender por que,
   no silenciarlo.
2. Marcar test como skip / xfail / pending sin issue tracked + root
   cause documentada: `pytest.mark.skip`, `it.skip`, `xfail`,
   `expected_failure` sin enlace a investigacion.
3. Re-intentar la misma operacion 3+ veces con variantes superficiales
   del mismo parche: el patron N=3 dispara `execution-supervisor`
   (SPEC-065). Tras attempt 3, parar y razonar.
4. Usar `--no-verify` en commits o push: los hooks existen por algo.
   Saltarlos es bypass de safety, no productividad.
5. Comentar o eliminar assertion en test para que pase: el test es
   contrato, no friccion a remover.
6. "Solo por esta vez" seguido de un atajo: los "solo por esta vez"
   se acumulan en deuda invisible.
7. Cambiar el threshold del scoring sin spec / sin justificacion ligada
   a la causa real: el threshold es decision, no variable libre.
8. Bajar criterios de aceptacion de una spec porque la implementacion
   no llega: la implementacion debe llegar, no los criterios bajar.
9. Marcar SPEC como IMPLEMENTED cuando los criterios de aceptacion no
   se cumplen integramente: solo IMPLEMENTED si los AC pasan.
10. Re-ejecutar tests "a ver si esta vez pasan" sin cambio causal: la
    flakiness es un sintoma, no aleatoriedad benigna.

## Que SI esta permitido (con justificacion documentada)

- Bajar threshold si la spec lo aprueba explicitamente con razon
  documentada (`Causal-Evidence:` poblado).
- Skip temporal con issue abierto en backlog + ETA de reactivacion +
  root cause documentada.
- Bypass de hook si hay incidente operativo declarado + `[hotfix]`
  trailer + commit follow-up para arreglar el hook.
- Re-intentar una operacion si el cambio entre intentos altera la
  causa hipotetizada (no solo el parche superficial).

## Por que importa

El daño de un atajo no es el atajo, es la repeticion. Cada vez que un
agente baja un threshold, instala el patron "baja threshold cuando
falle". Tres meses despues, los tests no garantizan nada porque sus
thresholds han bajado todos. El sistema deja de ser sistema y pasa a
ser teatro de sistema.

La causa raiz es mas cara de encontrar (15 min de investigacion vs 30s
de parche) pero MAS barata a largo plazo: no re-aparece, no genera
patrones de evasion, no degrada confianza en metricas.

## Quien consume esta memoria

- `memory-conflict-judge` (Recommendation Tribunal, SPEC-125): score 0
  + `veto: true` si una recomendacion viola estos patrones.
- `responsibility-judge` (SPEC-043 cuando implementado): bloquea
  PreToolUse Edit/Write que matche estos patrones en codigo.
- `execution-supervisor` (SPEC-065 cuando implementado): tras attempt
  3 del mismo action+target, exhibe esta memoria en el reflection.
- `recommendation-tribunal-orchestrator`: aggregator final usa este
  file como input de evidencia.
- Humano revisor (E1 SDD): referencia rapida al evaluar PRs.

## Bridge con SPEC-188 (P1 Failure Pattern Memory)

Cuando P1 este implementado, ocurrencias repetidas del mismo patron
(ej. "agente X bajo threshold N veces") se contaran en
`failure_patterns`. A `occurrences >= 10`, P1 sugiere promocion de
subpattern especifico a nueva regla `feedback_*.md`. Este fichero es
el bootstrap.

## Cambios

- 2026-06-04: creacion (SPEC-188 Fase 0, cierre G3). Contenido inicial
  derivado de SPEC-125, SPEC-043, verified-memory-axiom. Path elegido:
  `.claude/rules/domain/feedback/` (N1, semantically rule of behavior).
  Status: active.
