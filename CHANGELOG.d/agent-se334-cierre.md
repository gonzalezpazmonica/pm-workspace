---
version_bump: minor
section: Changed
---

### Changed

- `docs/specs/SE-334-vaults-scl-criteria-hardening.spec.md`: cierre verificado → IMPLEMENTED. AC-07 ajustado al estado real (CRIT-001 human_authored activado por la operadora 2026-08-20: 32 INFERRED / 1 human_authored, S5 dormido); nota de cierre en historial append-only.
- `tests/bats/test-se257-consolidacion.bats`: AC-1.4b corregido para reflejar 1 human_authored real (drift post-espec), sin cambiar el comportamiento de `criterio-validate.sh`. 66/66 BATS verdes.