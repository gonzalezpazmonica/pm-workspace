# Criterios de evaluación — eval-03-spec-compliance

## Puntuación (cada ítem = 1 punto, máximo 10)

- [ ] El juez spec-judge lidera el análisis de compliance
- [ ] Identifica correctamente que AC1 tiene desviación (GBP no está en la spec)
- [ ] Detecta la desviación en AC3: código HTTP 422 en lugar de 400
- [ ] Detecta la desviación en AC3: error code VALIDATION_ERROR en lugar de ITEMS_REQUIRED
- [ ] Confirma que AC2 (404 CUSTOMER_NOT_FOUND) está correctamente implementado
- [ ] Confirma que AC4 (cálculo del total) está correctamente implementado
- [ ] Confirma que AC5 (status DRAFT, 201) está correctamente implementado
- [ ] El veredicto es CHANGES_REQUIRED (hay desviaciones pero no son de seguridad)
- [ ] Las desviaciones identificadas son marcadas como bloqueantes para merge
- [ ] El fichero .review.crc incluye tabla de ACs con estado PASS/FAIL por cada uno

## Umbral de aceptación: mayor o igual a 7 sobre 10 puntos

## Dimensiones LLM-as-judge

| Dimensión | Peso | Criterios |
|---|---|---|
| Precisión | 40% | Identifica exactamente las 3 desviaciones reales (GBP, 422, VALIDATION_ERROR) |
| Completitud | 40% | Evalúa todos los ACs; tabla de compliance incluida en el veredicto |
| Ausencia de alucinaciones | 20% | No inventa desviaciones no presentes; no omite las 3 desviaciones reales |
