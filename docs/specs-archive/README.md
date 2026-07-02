# Specs Archive

Specs completados, abandonados o superseded. Se archivan al cerrar, no se borran.

## Gap historico (honestidad radical)

Los specs SE-143 a SE-252 (aprox. ~110 specs, procesados 2026-03 a 2026-07-02)
fueron mergeados sin archivar sus ficheros originales. Su estado final consta en
el frontmatter de `docs/propuestas/` (flipeados a IMPLEMENTED en sesion 2026-07-02).
La trazabilidad codigo vs spec para ese rango es parcialmente recuperable desde
`git log` y los titulos de los PRs mergeados.

## Procedimiento desde SE-253 en adelante

Al cerrar un spec (flip a IMPLEMENTED, DONE o ABANDONED):
1. `mv docs/propuestas/SE-XXX-*.md docs/specs-archive/YYYY/`
2. Anadir al frontmatter:
   - `closed_by_pr: "#NNN"`
   - `closed_date: "YYYY-MM-DD"`
   - `status: IMPLEMENTED` (o ABANDONED con motivo)
3. Entrada en `CHANGELOG.d/` con campo `spec: SE-XXX`

## Backfill (ultimos 30 dias -- recuperable)

Ver listado en este directorio. Specs anteriores a 2026-06-02 declarados perdidos.

## Estructura

```
docs/specs-archive/
  README.md          <- este fichero
  2026/              <- anio de cierre
    SE-XXX-*.md      <- copia de archivo con closed_by_pr y closed_date anadidos
```
