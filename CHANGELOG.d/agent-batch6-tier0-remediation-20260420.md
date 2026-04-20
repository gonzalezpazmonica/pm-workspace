### Added — Batch 6 (Tier 0+1 remediation from audit)

**4 new scripts + 5 test suites (98 tests)**:

- `scripts/spec-approval-gate.sh` (SE-051, Rule #8 enforcement).
- `scripts/baseline-tighten.sh` (SE-046, ratchet auto-tighten).
- `scripts/agents-catalog-sync.sh` (SE-047, catalog auto-regen from frontmatter).
- `scripts/rule-orphan-detector.sh` (SE-048, detect rules without references).
- `tests/test-claude-md-drift-check.bats` (SE-043, BATS coverage for existing script).

**Operational fixes applied (from audit)**:

- `docs/rules/domain/agents-catalog.md`: regenerated 56→65 agents (D5).
- `.ci-baseline/hook-critical-violations.count`: 10→5 (D6, CI-safe margin).

**Pending (next PR)**:

- SE-045 session-init split fast-path (isolated PR, risky hook).
- SE-044 SPEC-110 ID collision ADR (needs human decision).
- SE-050 SPEC-122 Slice 2+3 cierre.
- SE-052 Agent-size remediation plan.
- SE-054 SE-036 frontmatter Slices 2-3.

Ref: PR #[TBD], `output/audit-*-20260420.md`.
