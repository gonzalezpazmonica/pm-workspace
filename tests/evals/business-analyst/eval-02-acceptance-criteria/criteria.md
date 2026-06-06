# Criterios de evaluación — eval-02-acceptance-criteria

## Puntuación (cada ítem = 1 punto, máximo 10)

- [ ] Produce al menos 5 criterios de aceptación distintos con identificadores únicos (AC-NNN)
- [ ] Todos los ACs usan formato Given/When/Then estricto (no prosa libre)
- [ ] Incluye AC para aprobación nominal (todos los controles en nivel OK)
- [ ] Incluye AC para aprobación con excepción (control de nivel bajo + autorización de supervisor)
- [ ] Incluye AC para rechazo bloqueante (control crítico fallido no puede aprobarse)
- [ ] Incluye AC para restricción de auto-aprobación (técnico no puede aprobar su propio lote)
- [ ] Incluye AC para restricción del supervisor (no puede aprobar lotes de su propio equipo)
- [ ] Identifica y documenta al menos una ambigüedad de las reglas informales con la decisión tomada
- [ ] Cada AC tiene clasificación de tipo (nominal, alternativo, restricción)
- [ ] Los ACs son verificables automáticamente (sin necesidad de juicio humano para evaluarlos)

## Umbral de aceptación: mayor o igual a 7 sobre 10 puntos

## Dimensiones LLM-as-judge

| Dimensión | Peso | Criterios |
|---|---|---|
| Precisión | 40% | ACs derivados fielmente de las reglas de negocio; no inventa restricciones |
| Completitud | 40% | Los 5 escenarios clave cubiertos; ambigüedades documentadas |
| Ausencia de alucinaciones | 20% | No añade reglas de negocio no presentes en el texto de entrada |
