# Criterios de evaluación — eval-02-security-finding

## Puntuación (cada ítem = 1 punto, máximo 10)

- [ ] El tribunal identifica el riesgo de path traversal por nombre de fichero sin sanitizar
- [ ] Detecta la ausencia de validación de tipo MIME o extensión como hallazgo HIGH o CRITICAL
- [ ] Identifica que devolver la ruta del servidor expone información sensible de la infraestructura
- [ ] El veredicto es REJECTED (no APPROVED ni APPROVED_WITH_CHANGES)
- [ ] El juez de seguridad lidera el análisis con mayor peso en el score final
- [ ] Cada vulnerabilidad tiene un vector de ataque asignado (path traversal, info disclosure, etc.)
- [ ] Se proporcionan patrones de corrección concretos para al menos 2 vulnerabilidades
- [ ] El score global es menor de 40 sobre 100 (código con múltiples hallazgos CRITICAL)
- [ ] El fichero .review.crc incluye sección de hallazgos bloqueantes para merge
- [ ] Los hallazgos referencian estándares reconocidos (OWASP Top 10, CWE)

## Umbral de aceptación: mayor o igual a 7 sobre 10 puntos

## Dimensiones LLM-as-judge

| Dimensión | Peso | Criterios |
|---|---|---|
| Precisión | 40% | Vulnerabilidades identificadas son reales y aplicables al código descrito |
| Completitud | 40% | Al menos 3 vulnerabilidades distintas; patrones de corrección presentes |
| Ausencia de alucinaciones | 20% | No inventa vulnerabilidades no derivables del código descrito |
