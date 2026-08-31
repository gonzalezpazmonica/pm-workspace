---
version_bump: patch
section: Added
---

### Added

- SE-358 plan.md verificado: `plan-validate.py` (valida secciones Files/Order/Risks/Proof y extrae archivos) + `plan-diff-check.sh` (sync hook plan↔diff, mode warn/block, artefactos de proceso excluidos). El diff final se puede auditar contra el plan aprobado. 11 bats tests.
