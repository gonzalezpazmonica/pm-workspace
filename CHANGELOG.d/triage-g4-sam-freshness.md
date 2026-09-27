---
version_bump: patch
section: Fixed
---
- Triage grupo 4: `test-block-pat-file-write.bats` pasa a comprobar comportamiento (el grep del patrón antiguo se rompió con la regex de #1153); fixtures de G14 declaran `layer` (obligatorio desde SE-356). SAM (`.scm/sam.json`) regenerado: estaba obsoleto en main desde #1151 (MISSING_INPUT tras borrar un script). `resolve-pr-conflicts.sh` regenera SAM tras el capability map y `ci-extended-checks.sh` añade el check #11 SAM Freshness (solo lectura, `sam.py check`).
- SAM quedaba obsoleto tras cada squash merge: la procedencia guardada apunta al commit de la rama, ausente en un clon limpio de main, y `sam_model` trataba esa ausencia como contenido distinto. Ahora solo un commit existente con otros bytes invalida la procedencia (2 tests nuevos en `tests/test_sam.py`).
- `memory-store.sh search --mode grep` arrancaba igualmente el servidor de embeddings, y el proceso en segundo plano heredaba el fd 3 de bats: `test-memory-vector.bats` se colgaba hasta el timeout (900 s → 95 s). Ahora el modo grep no lo arranca, el lanzamiento cierra stdin y fd 3, y `SAVIA_EMBED_AUTOSTART=false` lo desactiva (tests nuevos en `tests/scripts/test-memory-store-embed-autostart.bats`).
- `federation-discover.sh` (SCL-009) entraba en bucle infinito con `--add ID` sin URL, `--remove` sin ID o `--pool` sin fichero: `shift N` con menos de N argumentos falla sin desplazar y el `while` repetía el mismo flag. Ahora valida la aridad y sale con exit 2. `test-scl-009-autodiscover.bats`: timeout 900 s → 13/13 en 2 s.
