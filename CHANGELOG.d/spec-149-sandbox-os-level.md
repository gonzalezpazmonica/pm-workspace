---
version_bump: minor
section: Added
---

### Added

- SPEC-149: Sandbox OS-level para modos autonomos (Capa A + Capa B + Capa C).
  - opencode.json: 8 reglas deny en permission.bash (comandos destructivos bloqueados en Capa A application-layer).
  - opencode.json: plugin opencode-sandbox declarado + experimental.sandbox block con policy_dir y fail_if_unavailable.
  - .opencode/sandbox-policies/: 5 policies YAML (default-readonly, overnight-sprint, code-improvement-loop, tech-research-agent, pentesting) con filesystem y network allowlists por modo.
  - scripts/savia-sandbox-doctor.sh: verifica las 3 capas con instrucciones accionables. Ubuntu 24.04 AppArmor caveat documentado con fix exacto.
  - docs/rules/domain/sandbox-os-policy.md: regla canonica con arquitectura de capas, limitaciones honestas y referencia a autonomous-safety.md.
  - tests/test-sandbox-spec149.bats: 19 tests cubriendo AC-01, AC-05, AC-06, AC-07, AC-08.
  - Nota: bwrap namespace isolation requiere fix AppArmor en Ubuntu 24.04 (warn en doctor, no bloqueante para Capa A).
