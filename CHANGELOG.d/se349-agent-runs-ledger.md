---
version_bump: patch
section: Added
---

### Added (SE-349 — Agent Runs Operations Ledger)

- Nuevo `scripts/savia-runs.sh`: ledger local de runs autónomos con **estado derivado
  en lectura** (Working / Needs you / In review / Ready to merge / Done / Terminated)
  y hechos durables (`activity_state`, `is_terminated`, hechos de PR) en
  `data/agent-runs-ledger.jsonl`. Inspirado en agent-orchestrator
  (Untrivial-ai): "never store display status — derive at read time".
- **Guardrail de terminación**: `finish` se niega si el run posee un PR `open|draft`
  vivo ("failed probes are NOT proof of death"); bypass explícito `--force` o `pr clear`.
- Skill nueva `agent-runs-board` que enseña a registrar y supervisar runs en el board.
- CRIT-001: todo el estado es local (JSONL gitignored), cero telemetría a proveedor
  (la telemetría PostHog de agent-orchestrator se rechaza explícitamente).
- 22 tests BATS en `tests/test-se-349-agent-runs-ledger.bats`.
