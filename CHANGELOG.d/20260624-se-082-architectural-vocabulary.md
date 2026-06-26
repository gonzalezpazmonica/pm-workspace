## SE-082 — Architectural vocabulary discipline (2026-06-24)

### Added
- `docs/rules/domain/architectural-vocabulary.md`: canonical 6-term vocabulary (Module/Interface/Seam/Adapter/Depth/Locality) with _Avoid_ rejection sets. Clean-room re-implementation of mattpocock/skills/improve-codebase-architecture/LANGUAGE.md (MIT). ≤89 LOC.
- `scripts/architectural-vocabulary-audit.sh`: static auditor scanning outputs for prohibited terms (boundary, component, service, API in architectural contexts). Warning-only mode; exit 0 always.
- Cross-references added to `docs/rules/domain/attention-anchor.md`, `.opencode/agents/architect.md`, `.opencode/agents/architecture-judge.md`.
- Three ratchet principles: deletion test, interface=test surface, one adapter=hypothetical seam.

### Tests
- 31 BATS tests in `tests/structure/test-architectural-vocabulary.bats` (all pass).

### Status
- SE-082 APPROVED → IMPLEMENTED
