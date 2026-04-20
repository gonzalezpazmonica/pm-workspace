### Added — Batch 7 (Tier 1 continuación)

**Scripts + tests**:
- `scripts/spec-id-duplicates-check.sh` (SE-044) + 27 tests, certified.
- `scripts/changelog-consolidate-if-needed.sh` (SE-053) + 23 tests, certified.
- `.claude/hooks/session-init-bootstrap.sh` (SE-045 Slice 1) — standalone async bootstrap, awaiting authorization to wire.

**Resolved**:
- SPEC-110 ID collision: polyglot REJECTED renamed to `SPEC-126-polyglot-developer-rejected.md`. Duplicate guard now PASS.
- `docs/decisions/adr-001-spec-110-id-collision-resolution.md` registrada.

**Blocked/pending**:
- SE-045 Slice 2 (replace session-init.sh) — sandbox requires explicit user authorization for critical hook self-modification.

Ref: PR #[TBD], `output/audit-arquitectura-20260420.md` D7/D21.
