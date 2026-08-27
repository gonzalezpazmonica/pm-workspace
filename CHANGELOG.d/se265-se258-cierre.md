---
version_bump: minor
section: Changed
---

### Changed (Batch 4 — SE-265 y SE-258 cierre)

- **SE-265 → IMPLEMENTED** (verificado 2026-08-27): `rules/court.rules.yaml`
  sección `models` (per_judge: security/correctness heavy, cognitive/spec fast,
  budget), 10 BATS verdes, `causal_chain` en findings. Ya implementado en #905;
  status alineado con la realidad.
- **SE-258 → IMPLEMENTED** (verificado): slices 1-3 (protección activos
  identitarios: ledger destrackeado, guard block-sensitive-tracking,
  sensitive-paths.yaml, tracked-vs-nivel.sh → "Zero N3+ tracked"; restore
  drill + verify-ledger-chain; /self-audit + battery) y hot-reload de
  MODEL_TIER_MAP en savia-foundation.ts ya existentes.
- **Nuevo (Slice 5 residual)**: job CI `dependency-audit` (npm audit high +
  pip list --outdated).
- Residual honesto documentado en la spec (Slice 4: SE-257 sin fichero en repo;
  el gate CHANGELOG de PR-Gate-8 sí está activo).
