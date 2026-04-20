# ADR-001 — Resolución colisión SPEC-110

> **Fecha**: 2026-04-20
> **Status**: ACCEPTED
> **Contexto**: SE-044 Slice 1, audit-arquitectura-20260420.md D7/D21
> **Decision owner**: Savia (propuesta autónoma tras auditoría)

## Contexto

`docs/propuestas/` contenía dos specs distintos compartiendo el mismo ID `SPEC-110`:

1. **SPEC-110-memoria-externa-canonica.md** — status `Draft`, activo.
   - Referenciado en `CLAUDE.md`: `## Usuario activo (SPEC-110)`.
   - Implementado parcialmente (test coverage en PR #592).
2. **SPEC-110-polyglot-developer.md** — status `REJECTED (2026-04-17)`.
   - Propuesta archivada tras análisis de viabilidad negativo.

La colisión corrompe referencias: cualquier enlace a "SPEC-110" es ambiguo.
Detectado por `scripts/spec-id-duplicates-check.sh` (SE-044 Slice 1).

## Decisión

1. **Mantener SPEC-110** para `memoria-externa-canonica.md` (es el activo).
2. **Renumerar** `polyglot-developer.md` → `SPEC-126` (siguiente libre).
   - Fichero renombrado a `SPEC-126-polyglot-developer-rejected.md`.
   - Campo `id:` actualizado a `SPEC-126` en frontmatter.
   - Título: `SPEC-126 — Polyglot Developer (renumbered from SPEC-110)`.
3. **Preservar status REJECTED**. No se resucita la propuesta.
4. **Gate**: `scripts/spec-id-duplicates-check.sh` pasa a ejecutarse en pre-commit (SE-044 Slice 2).

## Consecuencias

- Referencias a "SPEC-110" ahora apuntan inequívocamente a memoria-externa-canonica.
- `CLAUDE.md` no requiere cambio (ya apuntaba al concepto correcto).
- Cualquier documento que mencione "SPEC-110 polyglot" debe actualizarse a SPEC-126.
- ID `SPEC-110` queda blindado — el gate impide futuras colisiones.

## Alternativas consideradas

- **Archivar polyglot en `docs/archive/`**: rechazado porque no existe la convención establecida y renumerar preserva el estado histórico junto al resto de specs rejected.
- **Renumerar memoria-externa a SPEC-126**: rechazado — romperia referencias ya existentes en CLAUDE.md, PRs mergeados y tests BATS.

## Verificación

```bash
bash scripts/spec-id-duplicates-check.sh
# Expected: VERDICT PASS, Duplicates 0
```

## Referencias

- SE-044: `docs/propuestas/SE-044-spec-id-duplicate-guard-y-adr-resolucion.md`
- Audit: `output/audit-arquitectura-20260420.md` §Matriz D7/D21
- Rule #8: `docs/rules/domain/autonomous-safety.md`
