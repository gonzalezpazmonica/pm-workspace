---
version_bump: patch
section: Added
---

### Added

- **L19 Monitor de calidad de datos (SE-342 S3)** — `tabular-profile.py monitor`:
  - `monitor init FILE` guarda baseline determinista (filas, columnas, tipo y
    completeness por columna) en `~/.savia/data-quality/` (override
    `SAVIA_DQ_DIR`).
  - `monitor check FILE` compara contra baseline: drift de esquema (columnas
    nuevas/faltantes), completeness por columna (< `SAVIA_DQ_COMPLETENESS`,
    por defecto 95) y freshness (`SAVIA_DQ_FRESHNESS_DAYS`, por defecto 7).
    Verdict PASSO/WARN/FAIL; exit 0 si PASS.
  - Feature store verificado (integración con catálogo L17): features
    registradas con lineage `feeds` al dataset origen.
  - 6 tests BATS (init, PASS, drift, sin baseline, schema, feature store).