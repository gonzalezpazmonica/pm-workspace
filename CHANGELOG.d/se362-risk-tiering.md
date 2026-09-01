---
version_bump: patch
section: Added
---

### Added

- SE-362 Risk Tiering: `risk-tier.py` clasifica cambios por tier 1-4 (docs-only → T1, código → T2, secrets/migrations/push → T3, infra/prod/PII → T4, fail-closed → T3). `push-pr.sh --merge` consulta el tier antes de mergear: T3/T4 bloqueado sin review humana aun con grant. 7 pytest + 5 bats tests.
