# Criterios de evaluación — eval-02-auth-spec

## Puntuación (cada ítem = 1 punto, máximo 10)

- [ ] La spec tiene frontmatter YAML con `spec_id`, `title`, `status` válidos
- [ ] Cubre las 3 operaciones requeridas (iniciar, renovar, cerrar sesión)
- [ ] Especifica TTL del token corto (15 min) y token largo (7 días) explícitamente
- [ ] Incluye AC para escenario de sesión sospechosa (2 orígenes en menos de 60s)
- [ ] Especifica que el token largo se almacena como hash en base de datos
- [ ] No contiene placeholders TODO/TBD sin resolver
- [ ] Incluye los 4 datos del token firmado: identificador, expiración, emisión, rol
- [ ] Define al menos 3 test scenarios negativos (token caducado, inválido, revocado)
- [ ] Especifica el mecanismo de firma y gestión del secreto via variable de entorno
- [ ] Los ACs son verificables por un agente automatizado sin ambigüedad

## Umbral de aceptación: ≥ 7/10 puntos

## Dimensiones LLM-as-judge

| Dimensión | Peso | Criterios |
|---|---|---|
| Precisión | 40% | No inventa mecanismos no solicitados; datos del token exactos |
| Completitud | 40% | Las 3 operaciones cubiertas; todos los escenarios de error presentes |
| Ausencia de alucinaciones | 20% | Referencias a .NET Identity o BCrypt correctas si se mencionan |
