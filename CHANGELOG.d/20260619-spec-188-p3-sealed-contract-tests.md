## SPEC-188-P3 — Sealed Contract Tests guard hook (2026-06-19)

### Added
- .claude/hooks/contract-test-guard.sh: PreToolUse hook that blocks Edit/Write to allowlisted contract tests from agent/* branches (69 LOC)
- .claude/contracts/allowlist.txt: 5 sealed contract tests pre-committed (block-force-push, confidentiality-sign, pii-gate, permissions-wildcard, validate-agent-permissions)
- tests/hooks/test-contract-test-guard.bats: 24 tests covering block/allow paths, bypass via [contract-change|add|remove], env var guards, latency
- docs/specs/SPEC-188-P3-sealed-contract-tests.spec.md: SDD spec with falsifiable AC
- docs/specs/SPEC-188-P3-precommitment.md: pre-commitment of selection criteria, hard limits, abort criteria

### Changed
- .claude/settings.json: registers contract-test-guard hook on PreToolUse Edit|Write

Adversarial post-impl review identified 4 CRITICAL/HIGH issues, all fixed:
- Hook reduced from 113 to 69 LOC (under hard limit 80)
- _SAVIA_INTERNAL_TEST_BRANCH guard requires BATS_TEST_FILENAME or CI or SAVIA_TEST_MODE
- [contract-change|add|remove] commit message bypass implemented and tested
- substring match replaced by exact + REPO_ROOT-normalized suffix match
