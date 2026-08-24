---
version_bump: patch
section: Added
---

### Added

- **L14 (parcial) — cobertura de tests de `vaults-backup-cron.sh`** — 
  `tests/test-vaults-backup.bats` (7 tests):
  - `run` genera por cúpula `tar.gz` + `git bundle` + `sha256` (assert por
    find, robusto ante timestamps).
  - `--verify` valida integridad (gzip -t + sha256 -c) y `--status` reporta
    dir/retention.
  - `nc-push` con destino caído es **fail-safe**: no rompe el backup local
    (best-effort, CRIT-001: destino = infra propia, cero egress).
  - Verificación de no-egress (sin SDK de terceros).
- **`SAVIA_VAULTS_DIR` override** en `vaults-backup-cron.sh`: permite apuntar
  el origen de cúpulas a un directorio distinto de `$HOME/savia/vaults`
  (necesario para tests aislados y back-ups portables; retrocompatible: el
  default es el de siempre).