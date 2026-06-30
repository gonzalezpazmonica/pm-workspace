## SE-102 — Eras timeline consolidation

- Added `docs/eras-timeline.md`: tabla completa de todas las Eras (1-124 batch + 182-250+ individual), columnas Era/Versión/Fecha/Estado/Specs clave/Resumen
- Added `scripts/eras-timeline-generate.sh`: genera eras-timeline.md desde ROADMAP.md, soporta --check mode (exit 1 si desactualizado)
- Added `tests/bats/test-se-102-eras-timeline.bats`: 8 tests (exists, table, columns, >=20 eras, footer, script executable, check mode, regenerate)
- All 8 tests passing

Spec: docs/propuestas/SE-102-eras-timeline.md
