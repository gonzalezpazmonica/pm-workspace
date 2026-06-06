# Criterios de evaluación — eval-03-domain-rules

## Puntuación (cada ítem = 1 punto, máximo 10)

- [ ] El glosario incluye al menos 6 términos del dominio con definición precisa
- [ ] Las reglas de negocio están numeradas y tienen precondiciones y postcondiciones
- [ ] Cubre las reglas de cálculo de precio (tarifa_base x multiplicador_perfil)
- [ ] Cubre los 4 tramos de descuento por volumen con sus rangos exactos
- [ ] Identifica al menos 3 casos límite (exactamente 100h, exactamente 500h, exactamente 1000h)
- [ ] Incluye la invariante de contratos Enterprise con mínimo de 500 horas
- [ ] Incluye la regla de bloqueo por facturas vencidas (+30 días)
- [ ] Formula al menos 3 preguntas de clarificación pertinentes para el cliente
- [ ] Los invariantes del dominio están separados de las reglas de negocio
- [ ] El modelado es suficiente para que un arquitecto pueda diseñar las entidades sin más input

## Umbral de aceptación: mayor o igual a 7 sobre 10 puntos

## Dimensiones LLM-as-judge

| Dimensión | Peso | Criterios |
|---|---|---|
| Precisión | 40% | Reglas derivadas fielmente del texto; multiplicadores y rangos exactos |
| Completitud | 40% | Los 5 entregables solicitados presentes; casos límite identificados |
| Ausencia de alucinaciones | 20% | No inventa reglas no presentes; preguntas de clarificación son pertinentes |
