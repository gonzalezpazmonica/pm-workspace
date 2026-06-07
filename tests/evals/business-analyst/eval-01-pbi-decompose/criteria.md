# Criterios de evaluación — eval-01-pbi-decompose

## Puntuación (cada ítem = 1 punto, máximo 10)

- [ ] La descomposición produce al menos 5 tasks distintas (dominio, persistencia, email, mensajes, API preferencias)
- [ ] Cada task tiene estimación en horas (no en story points, no "pequeño/mediano/grande")
- [ ] Cada task especifica la capa técnica afectada (Domain, Application, Infrastructure, API, Frontend)
- [ ] Las dependencias entre tasks están documentadas (no todas pueden ser independientes)
- [ ] Los criterios de aceptación de cada task son verificables por un agente automatizado
- [ ] Incluye task para el mecanismo de disparo de alertas cuando se superan umbrales
- [ ] Las estimaciones son realistas (una task no puede ser menor de 1h ni mayor de 8h sin justificación)
- [ ] El total de horas estimadas es coherente con la complejidad del PBI (entre 20h y 60h)
- [ ] No hay tareas duplicadas ni con scope solapado
- [ ] El business-analyst identifica al menos un riesgo técnico o dependencia externa

## Umbral de aceptación: mayor o igual a 7 sobre 10 puntos

## Dimensiones LLM-as-judge

| Dimensión | Peso | Criterios |
|---|---|---|
| Precisión | 40% | Tasks cubren exactamente lo solicitado; no incluye scope fuera del PBI |
| Completitud | 40% | Todos los canales cubiertos; mecanismo de disparo incluido |
| Ausencia de alucinaciones | 20% | No inventa integraciones externas no mencionadas; estimaciones plausibles |
