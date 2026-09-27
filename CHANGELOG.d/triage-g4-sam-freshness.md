---
version_bump: patch
section: Fixed
---
- Triage grupo 4: `test-block-pat-file-write.bats` pasa a comprobar comportamiento (el grep del patrón antiguo se rompió con la regex de #1153); fixtures de G14 declaran `layer` (obligatorio desde SE-356). SAM (`.scm/sam.json`) regenerado: estaba obsoleto en main desde #1151 (MISSING_INPUT tras borrar un script). `resolve-pr-conflicts.sh` regenera SAM tras el capability map y `ci-extended-checks.sh` añade el check #11 SAM Freshness (solo lectura, `sam.py check`).
