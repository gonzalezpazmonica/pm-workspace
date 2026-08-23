---
version_bump: minor
section: Added
---

### Added

- L13 Savia Metacognition F4: recalibración desde señal real — `meta-recalibra-ledger.sh` convierte el ledger de ciclo de vida del bucle SCL (activación humana canary→active = success; revert = fail) en entradas de calibración para `meta-recalibrate.sh`. Cierra el bucle sin LLM (CRIT-001); la curva nutrida la consulta meta-monitor. 8 tests BATS.