---
version_bump: patch
section: Added
---

### Added

- **SE-342 Capa de Inteligencia de Datos Local** — `docs/specs/SE-342-data-intelligence-local.spec.md`:
  - Analisis de capacidades de datos + IA de la plataforma lakehouse de
    referencia (22 capacidades) y mapeo contra el stack local de Savia
    (15 cubiertas, 3 parciales, 4 gaps).
  - 5 slices priorizados + 1 opcional (S1-S6): catálogo de activos de datos con
    lineage, experiment tracking, monitor de calidad + feature store, gateway de
    modelos, prediccion asistida local y vector store hibrido en cupulas.
  - CRIT-001 explicito: sin datos fuera de infraestructura propia.
- **Savia Domains — `docs/domains/savia-domains-catalog.md`** (Labs L23):
  - Catalogo abierto N1 de 34 dominios / 11 categorias para cupulas de
    conocimiento por vertical.
  - Exclusiones de dominios sensibles (quimica, farmacia, medicina, salud,
    armamento, biotecnologia dual).
  - Direccion estrategica: Savia Domains + SaviaVaults como capa de datos por
    dominio soberana, local y libre (sección 6).