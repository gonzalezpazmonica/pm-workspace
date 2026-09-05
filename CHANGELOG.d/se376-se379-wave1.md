---
version_bump: patch
section: Added
---
- **SE-379 Release & Metadata Invariants** (`scripts/release-invariants.sh`): 7 invariantes verificables (VERSION_REGRESSION, CHANGELOG_VERSION_MISMATCH, CAPABILITY_COUNT_MISMATCH, STALE_COUNTER, STALE_TRANSLATION, ROADMAP_TIMESTAMP_DRIFT, GENERATED_VIEW_DRIFT) + 7 fixtures y bats. Contadores de README/traducciones derivados a valores reales (567/88/135/124) — cierra la divergencia 532/65/86/58.
- **SE-376 Quality Debt Burn-down**: `docs/propuestas/SE-376-debt-budget.yaml` (ratchet anti-subida, wave 0 = freeze en 132) + `scripts/debt-budget-check.sh` + inventario clasificado de 132 skills (8 DELETE / 124 REFACTOR, propuestas).
- Specs SE-375..384 actualizadas a APPROVED (aprobación Mónica 2026-09-05) con OpenCode Implementation Plan.
