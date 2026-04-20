---
spec_id: SPEC-095
title: Competitive Architects — Parallel Design Generation
status: IMPLEMENTED
origin: Anvil research (ppazosp/anvil, 2026-04-08)
severity: Media
effort: ~2h
---

# SPEC-095: Competitive Architects

## Problema

`/spec-design` genera un único diseño técnico con un solo subagente.
Esto produce un output razonable pero sin exploración de alternativas.
El usuario no ve trade-offs reales porque solo hay una propuesta.

Inspirado en Anvil (ppazosp/anvil): `/strike` lanza 2-3 arquitectos
en paralelo con filosofías diferentes y selecciona el mejor.

## Solución

Script `scripts/competitive-design.sh` que:

1. Recibe un spec path y genera 3 diseños con filosofías diferentes
2. Cada filosofía es un prompt variante para el subagente architect:
   - **Minimal**: mínimos cambios al codebase, reutilizar lo existente
   - **Clean**: clean architecture ideal, sin compromisos legacy
   - **Pragmatic**: balance entre deuda técnica y velocidad de entrega
3. Los 3 se ejecutan en paralelo (subagentes independientes)
4. Un evaluador (reflection-validator) puntúa cada diseño en 4 criterios:
   - Complejidad de implementación (0-10)
   - Alineación con spec (0-10)
   - Mantenibilidad a 6 meses (0-10)
   - Riesgo de regresión (0-10, inverso)
5. Output: los 3 diseños + tabla comparativa + recomendación

### Formato de salida

```markdown
# Competitive Design — {spec-name}

## Comparativa

| Criterio | Minimal | Clean | Pragmatic |
|----------|---------|-------|-----------|
| Complejidad impl. | 8 | 5 | 7 |
| Alineación spec | 7 | 9 | 8 |
| Mantenibilidad 6m | 6 | 9 | 8 |
| Riesgo regresión | 9 | 5 | 7 |
| **Total** | **30** | **28** | **30** |

## Recomendación: Pragmatic
Mejor balance entre velocidad de entrega y mantenibilidad...

## Diseño Minimal
[contenido completo]

## Diseño Clean
[contenido completo]

## Diseño Pragmatic
[contenido completo]
```

## Integración con /spec-design

Añadir flag `--competitive` a `/spec-design`:
- Sin flag: comportamiento actual (1 diseño, rápido)
- Con `--competitive`: lanza 3 diseños paralelos + evaluación
- Output guardado en `{spec-path}-competitive-design.md`

## Criterios de aceptación

- [ ] Script `scripts/competitive-design.sh` con generate/evaluate/compare subcomandos
- [ ] 3 filosofías generan diseños distintos (no copias)
- [ ] Evaluación objetiva con 4 criterios numéricos
- [ ] Tabla comparativa en formato markdown
- [ ] Funciona sin spec (modo standalone con descripción textual)
- [ ] Tests BATS >= 10 casos
