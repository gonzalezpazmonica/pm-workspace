# Criterios de evaluación — eval-03-api-spec

## Puntuación (cada ítem = 1 punto, máximo 10)

- [ ] La spec tiene frontmatter YAML con `spec_id`, `title`, `status` válidos
- [ ] Documenta los 5 query params con tipos, rangos y defaults correctos
- [ ] Especifica paginación basada en cursor (no offset) con next_cursor y prev_cursor
- [ ] Incluye el campo `pagination.total_count` y `pagination.has_more` en la respuesta
- [ ] Define el comportamiento de cursor inválido/expirado con error code `CURSOR_INVALID`
- [ ] Especifica que múltiples filtros se combinan con AND lógico
- [ ] No contiene placeholders TODO/TBD sin resolver
- [ ] Incluye al menos un ejemplo completo de request/response (no esquemático)
- [ ] Define el AC de límite fuera de rango (limit < 1 o > 100 → 400)
- [ ] Los ACs son verificables por un agente automatizado sin ambigüedad

## Umbral de aceptación: ≥ 7/10 puntos

## Dimensiones LLM-as-judge

| Dimensión | Peso | Criterios |
|---|---|---|
| Precisión | 40% | Cursor-based pagination descrita correctamente; no confunde con offset |
| Completitud | 40% | Todos los query params cubiertos; todos los error cases presentes |
| Ausencia de alucinaciones | 20% | No inventa params no solicitados; error codes son los especificados |
