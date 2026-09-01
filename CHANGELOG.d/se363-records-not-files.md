---
version_bump: patch
section: Added
---

### Added

- SE-363 Registros-no-archivos: `governance-sync.py` extrae los CRIT de CRITERIO.md a un registro JSONL consultable (`data/governance/criterios.jsonl`) con estado/aprobación; `governance-query.sh` consulta por status/approved-by. El Markdown es la vista, el registro es el dato. 5 pytest + 5 bats tests.
