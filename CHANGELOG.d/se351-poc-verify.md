---
version_bump: minor
section: Added
spec: SE-351
---

### Added (SE-351 — Verificación binaria de PoCs, lección CyberGym)

- Nuevo `scripts/poc-verify.sh`: verificador binario de PoCs **independiente del
  LLM** — evalúa exit code / regex sobre el output del target y emite
  `VERDICT: VERIFIED|NOT_VERIFIED|TIMEOUT` con recibo JSON auditable.
- **Gate de EXPLOITED en el pipeline pentester**: un hallazgo solo pasa a L3 si
  `poc-verify.sh` devuelve `VERIFIED` contra el oráculo del target. "Facts, not
  claims" (FxC): la evidencia la produce el programa, no el agente.
- `security-auditor` puede re-ejecutar la verificación para confirmar/desmentir.
- Oráculos configurables en `rules/poc-verify/` (modos: exit_code_nonzero, regex,
  combined; targets: command, docker con `network=none`, http).
- CRIT-001: PoCs solo en entornos controlados (Docker local aislado o comando
  local time-boxed), recibo con preview acotado (2 KB, anti-leak N3+), cero red.
- Nota de investigación: `output/research/cybergym-20260830.md`.
- 17 tests BATS en `tests/test-se-351-poc-verify.bats`.
