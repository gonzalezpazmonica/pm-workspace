---
version_bump: patch
section: Added
---

### Added

- **L17 Catálogo local de activos de datos con lineage (SE-342 S1)** —
  `scripts/savia-catalog.py`:
  - Registro de activos tipados: `dataset`, `feature`, `model`, `report` con
    nivel de confidencialidad obligatorio N1/N2/N3/N4b y project/source.
  - Lineage dirigido determinista (`feeds`, `trained_on`, `used_in`) con
    recorrido transitivo acotado (hasta 3 hops) hacia arriba y abajo.
  - Guard strict de niveles: rechaza cadenas que asciendan de sensibilidad
    (N1 → N3, exit 3) salvo `SAVIA_CATALOG_STRICT=0`.
  - Persistencia en la misma SQLite del knowledge-graph local (zero egress,
    CRIT-001); decisión ADOPTAR-OSS del POC: se extiende el grafo local en
    lugar de importar OpenMetadata/DataHub.
  - 11 tests BATS (registro, niveles, lineage, guard).