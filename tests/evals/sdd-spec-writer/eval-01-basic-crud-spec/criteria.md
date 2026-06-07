# Criterios de evaluación — eval-01-basic-crud-spec

## Puntuación (cada ítem = 1 punto, máximo 10)

- [ ] La spec tiene frontmatter YAML con `spec_id`, `title`, `status` válidos
- [ ] Define al menos 5 Acceptance Criteria medibles en formato Given/When/Then
- [ ] Especifica tipos y restricciones de todos los campos de entrada (title, description, assignee_id, priority)
- [ ] Incluye al menos 2 casos de error HTTP con códigos específicos (400, 404, 409)
- [ ] Menciona la capa de implementación correcta (API → Application → Domain, sin lógica en controller)
- [ ] No contiene placeholders TODO/TBD sin resolver
- [ ] Los ACs son verificables por un agente automatizado (sin ambigüedad)
- [ ] Incluye al menos un test scenario negativo (campo obligatorio ausente)
- [ ] Especifica el formato de respuesta de error (estructura JSON del cuerpo)
- [ ] Cita o referencia el contexto de dominio (gestión de tareas de laboratorio)

## Umbral de aceptación: ≥ 7/10 puntos

## Dimensiones LLM-as-judge

| Dimensión | Peso | Criterios |
|---|---|---|
| Precisión | 40% | No inventa endpoints, campos o comportamientos no solicitados |
| Completitud | 40% | Cubre todos los ACs del input, ningún campo omitido |
| Ausencia de alucinaciones | 20% | Referencias a librerías/frameworks reales y disponibles |
