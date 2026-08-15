# Domain: Evidence-First Development

> Desarrollo guiado por evidencia ejecutable en lugar de revisión línea a línea.
> Ref: AmazingAng/old-coder (MIT) — pattern only, prosa propia.

## Problema que resuelve

El line-by-line review de código generado por agentes no escala: cuando el
volumen de output crece, un humano no puede leerlo todo. La confianza tiene que
venir de **restricciones ejecutables** (tests, tipos, cobertura, mutación), no
de inspección manual.

## Métrica canónica

La confianza se articula en dos artefactos, no en una métrica única:

1. **SPEC** (antes del código): criterios de aceptación ejecutables + invariantes
   que deben sobrevivir + setup plan con cada dependencia justificada. Aprobado
   por el humano — el único artefacto que rompe la correlación todo-autor-mismo-agente.
2. **EVIDENCE** (después del código): números reales de una sola ejecución fresca,
   reproducibles con un entry-point (`tools/gauntlet.sh`). El humano lee el
   informe, no el código.

El gauntlet intermedio son las capas: suite completa, tipos+lint, cobertura
changed-line, mutación, property-based, ejecución real, supply chain, suite health.

## Límites honestos

El gauntlet **no** demuestra que el SPEC cubre todo lo importante, ni es
auto-autenticable (un checker puede ser unsound, un mapeo puede sobre-afirmar).
Por eso el SPEC va al humano, y EVIDENCE reporta confianza en capas, nunca
prueba absoluta. Ver `docs/rules/domain/checker-fail-closed.md`.

## Anti-gaming (por qué existe la disciplina)

Un agente que se corrige a sí mismo puede debilitar un test para que pase,
editar test+implementación a la vez, o perseguir el número de cobertura. Las
anti-gaming rules (ver SKILL.md) son el contrato que hace que el gauntlet sea
difícil de falsear.

## Confidencialidad

Sin implicaciones N3/N4. Opera sobre el código del proyecto y herramientas
off-the-shelf; no extrae datos fuera del workspace salvo dependencias declaradas
en el SPEC.
