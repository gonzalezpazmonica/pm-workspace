---
version_bump: patch
section: Added
---

### Added

- **L18 Experiment tracking local (SE-342 S2)** — `slm-registry.sh run`:
  - Subcomando `run --run-id ID [--base-model M] [--metrics JSON] [--params JSON]
    [--artifact PATH] [--dataset NAME] [--catalog-db DB]`: registra experimentos
    en el manifest del registry con params, métricas y artefacto.
  - Lineage opcional al catálogo L17: registra `run:<id>` como `model` con
    `trained_on` al dataset origen (`--dataset` + `--catalog-db`).
  - Determinista y local (manifest JSON + catálogo SQLite local, CRIT-001).
  - 6 tests BATS (manifest, validación, duplicados, lineage).