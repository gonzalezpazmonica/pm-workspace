# Criterios de evaluación — eval-01-simple-verdict

## Puntuación (cada ítem = 1 punto, máximo 10)

- [ ] El court-orchestrator convoca al menos 3 jueces distintos (seguridad, correctitud, arquitectura)
- [ ] Detecta la vulnerabilidad por concatenación directa de parámetros en queries
- [ ] Produce un veredicto CHANGES_REQUIRED o REJECTED (no APPROVED para código con vulnerabilidad CRITICAL)
- [ ] El fichero de salida tiene formato .review.crc con secciones estructuradas
- [ ] Cada hallazgo tiene severidad asignada (CRITICAL para la concatenación de parámetros)
- [ ] El score global refleja la severidad (debe ser menor de 50 para vulnerabilidad CRITICAL)
- [ ] Identifica el uso de DateTime.Now en lugar de DateTime.UtcNow como hallazgo
- [ ] Señala la ausencia de paginación en el método de listado como hallazgo de rendimiento
- [ ] Los hallazgos tienen referencias a reglas o estándares (OWASP, CWE)
- [ ] El veredicto incluye ciclos de corrección necesarios antes de merge

## Umbral de aceptación: mayor o igual a 7 sobre 10 puntos

## Dimensiones LLM-as-judge

| Dimensión | Peso | Criterios |
|---|---|---|
| Precisión | 40% | Hallazgos reales no inventados; vulnerabilidad por concatenación es el hallazgo principal |
| Completitud | 40% | Al menos 3 hallazgos distintos identificados; veredicto emitido con ciclos |
| Ausencia de alucinaciones | 20% | Referencias a CWE u OWASP existen y son aplicables al caso |
