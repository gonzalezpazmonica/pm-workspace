---
version_bump: patch
section: Fixed
---

### Fixed

- Prueba de fuego 2026-08-23: el recall SCL y el CLI de cúpulas (savia-vaults) requieren node≥22; sin node en el entorno el recall degradaba vacío silencioso. Fix: `savia-install.sh` auto-instala Node en `~/.savia/node` (infra propia, CRIT-001, idempotente) y `session-init.sh` exporta ese bin al PATH en cada arranque. Verificado: recall con node computa `shadow_hits` sobre SaviaLearning.