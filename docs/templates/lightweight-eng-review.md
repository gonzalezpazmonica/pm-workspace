# Lightweight Engineering Review — Template

> Copiar este fichero para cada cambio de infraestructura.
> Guardar en: `docs/design/{YYYY-MM-DD}-{descripcion}.md`
> Regla completa: `docs/rules/domain/lightweight-eng-review.md`

---

**Cambio**: [nombre corto del cambio]  
**Fecha**: YYYY-MM-DD  
**Autor**: [quien lo propone]  
**Spec**: SE-XXX (si aplica)  

---

## Problem

[Qué falla o qué falta. 1-3 frases concretas.]

## Root Cause

[Por qué existe el problema. Causa raíz, no síntoma.]

## Non-Goals

- [Qué NO se resuelve con este cambio]
- [Scope explícito de lo excluido]

## Design

[La solución. Pseudocódigo, bash, o descripción de los ficheros a crear/modificar.]

```bash
# ejemplo si aplica
```

## Data Flow

```
[componente A] → [acción] → [componente B] → [resultado]
```

## Edge Cases

| Caso | Comportamiento esperado |
|---|---|
| [caso límite 1] | [cómo se maneja] |
| [caso límite 2] | [cómo se maneja] |
| [caso límite 3] | [cómo se maneja] |

## Test Plan

- [ ] BATS suite: `tests/test-[nombre].bats`
- [ ] Tests nuevos: N
- [ ] Tests modificados: N
- [ ] Score auditor ≥ 80

## Rollout

[Cómo se activa: PR, script, feature flag, etc. Reversible si hay problema.]

## Lightweight Eng Review

- [ ] **Failure modes cubiertos** — ¿qué pasa si el script/hook falla?
- [ ] **Blast radius estimado** — ¿qué se rompe si hay un bug? ¿es aislado?
- [ ] **Test coverage** — ≥80 BATS score, CI no bloquea
- [ ] **Residual risks** — riesgos conocidos y aceptados
