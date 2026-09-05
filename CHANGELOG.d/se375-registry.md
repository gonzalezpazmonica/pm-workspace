---
version_bump: patch
section: Added
---
- **SE-375 Canonical Capability Registry (S1)**: generate-capability-map.py emite `.scm/registry.json` (1446 capabilities, ids únicos, determinista) con campos id/kind/source/status/owner_domain/intents/risk_level/frontend_support/depends_on/tests/replaced_by. --check valida también el registry. Kinds rule/hook diferidos a S2 (documentado en deferred_kinds). Bats: RN-07, RN-09, campos mínimos. GENERATED_VIEW_DRIFT (SE-379) ahora compara también registry.json.
