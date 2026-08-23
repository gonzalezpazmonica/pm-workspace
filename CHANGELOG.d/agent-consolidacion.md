---
version_bump: minor
section: Added
---

### Added

- SPEC-CONSOLIDACION-20260823: sanitización completa post-1000 PRs — 8 R implementados.
- R1 (P8): parser de cron humano (`daily 08:30`, `weekly fri 09:15`) en `store.py` + comandos `run-due`/`compute`; el orquestador diario ya computa `next_run` y salta solo.
- R2 (P3/P8): SessionStart dispara `run-due --max 2` (loops autónomos) + ítem informativo de lecciones SCL activas.
- R3 (P7): `savia-bootstrap-log.sh` — log de instalación append-only (tsv diario + rotación 200 líneas), nunca rompe el arranque.
- R4 (P6): `savia-install.sh` — bootstrap central idempotente (memory-deps, automations+orquestador, plugin, merge-drivers, memory-bootstrap) con log; integrado en `install.sh` como paso de consolidación.
- R5 (P2): calibración self-heal (meta-monitor falla abierto, recalibrate auto-crea curva).
- R7 (P4): 3 LPs de la sesión 2026-08-23 persistidas en la cúpula SaviaLearning.
- R8 (P5): getting-started ES+EN con sección 2b (instalador + capacidades nuevas).
- 13 tests BATS de consolidación (`tests/test-consolidacion-20260823.bats`).