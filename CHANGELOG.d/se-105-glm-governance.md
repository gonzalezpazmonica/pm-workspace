# SE-105 — GLM v1.0 Governance Layer Manifest

**Date**: 2026-06-24
**Status**: IMPLEMENTED
**Effort**: M 4h

## Summary

Adopted Governance Layer Manifest v1.0 — a machine-readable declaration of
Savia's governance boundaries, capabilities, constraints, and explicit
non-claims. Enables external consumers (auditors, compliance, enterprise
procurement) to programmatically understand what Savia does and does not do.

## Files added

- `.well-known/governance-layer-manifest.json` — GLM v1.0 canonical JSON manifest with 5 surfaces (substrate/witness/boundary/closure/reviewability), 7 explicit non-claims, consumer boundary constraint, composable layer types, and SHA-256 tamper-evident digest
- `.opencode/governance-manifest.yaml` — Workspace-internal operational YAML view with capabilities, constraints, data governance, and interoperability declarations
- `scripts/glm-compute-digest.sh` — Computes SHA-256 of manifest and updates manifest_digest.value in-place
- `scripts/glm-verify.sh` — Verifies stored digest matches computed digest
- `scripts/glm-validate.sh` — Full validation: JSON validity, enforcement paths, anchor files, audit recency, digest status. Output: PASS | WARN | FAIL
- `docs/rules/domain/glm-governance-protocol.md` — Canonical rule documenting GLM, update protocol, how to add capabilities/constraints, relationship to existing governance docs
- `tests/bats/test-se-105-glm.bats` — 18 BATS tests covering all ACs

## Acceptance criteria

- [x] AC-1: `.well-known/governance-layer-manifest.json` with 5 surfaces declared
- [x] AC-2: 7 explicit_non_claims declared (>= 5 required)
- [x] AC-3: consumer_boundary_constraint — 2-paragraph authoritative statement
- [x] AC-4: composable_with_types with 5 layer types
- [x] AC-5: `scripts/glm-compute-digest.sh` + `scripts/glm-verify.sh` + digest verified
- [x] AC-6: `docs/rules/domain/glm-governance-protocol.md` — 130 lines (<= 150 required)
- [x] AC-7: Manifest in `.well-known/` (repo only, not served on web)

## Tests

18 BATS tests in `tests/bats/test-se-105-glm.bats`. All pass.
