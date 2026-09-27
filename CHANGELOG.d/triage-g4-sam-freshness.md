---
version_bump: patch
section: Fixed
---
- Triage grupo 4: `test-block-pat-file-write.bats` pasa a comprobar comportamiento (el grep del patrón antiguo se rompió con la regex de #1153); fixtures de G14 declaran `layer` (obligatorio desde SE-356). SAM (`.scm/sam.json`) regenerado: estaba obsoleto en main desde #1151 (MISSING_INPUT tras borrar un script). `resolve-pr-conflicts.sh` regenera SAM tras el capability map y `ci-extended-checks.sh` añade el check #11 SAM Freshness (solo lectura, `sam.py check`).
- SAM quedaba obsoleto tras cada squash merge: la procedencia guardada apunta al commit de la rama, ausente en un clon limpio de main, y `sam_model` trataba esa ausencia como contenido distinto. Ahora solo un commit existente con otros bytes invalida la procedencia (2 tests nuevos en `tests/test_sam.py`).
