---
id: SPEC-055
status: IMPLEMENTED
priority: alta
applied_at: "2026-03-29"
implemented_at: "2026-04-25"
era: 186
---

# SPEC-055 — Test Auditor System

**Status:** IMPLEMENTED | **Author:** Savia | **Date:** 2026-03-29

## Problem

pm-workspace has 30+ test files but no way to judge test QUALITY. A test that
only checks `[ -f script.sh ]` passes CI but catches zero regressions. The
existing `audit-test-quality.sh` classifies tests into L0-L3 levels but does
not produce actionable scores, does not certify tests, and does not gate CI.

We need a deterministic judge that scores each test 0-100 against 9 criteria,
certifies passing tests with an embedded hash, and blocks CI on low-quality tests.

## Solution

Three scripts forming a test quality pipeline:

1. **test-auditor.sh** — Scores each `.bats` test file against 9 criteria (100 pts).
   Produces JSON output. Embeds certification hash in test file header on request.
2. **test-coverage-checker.sh** — Verifies every script in `scripts/` has a test.
3. **ci-test-quality-gate.sh** — Orchestrates both, gates CI on score >= 80.

## Scoring Criteria (100 points)

| # | Criterion | Points | Detection |
|---|-----------|--------|-----------|
| 1 | Exists and executable | 10 | File exists, has shebang, is executable |
| 2 | Safety verification | 10 | Tests verify target has `set -uo pipefail` |
| 3 | Positive cases | 15 | At least 3 `@test` with positive assertions |
| 4 | Negative cases | 15 | At least 2 `@test` for errors (missing args, bad input) |
| 5 | Edge cases | 10 | Tests for empty input, boundary, large input |
| 6 | Isolation | 10 | Uses `setup()`/`teardown()`, `mktemp`, no side effects |
| 7 | Coverage breadth | 10 | Tests >= 60% of target functions/features |
| 8 | Spec/doc reference | 10 | References SPEC doc or verifies doc exists |
| 9 | Assertion quality | 10 | Uses specific assertions, not just exit code |

All detection is deterministic: regex and pattern matching, zero LLM calls.

## Certification Hash

Format (line 2 of test file, after shebang):
```
# audit: score=87 hash=a1b2c3d4 date=2026-03-29
```

Hash = first 8 chars of `sha256(filename + score + date)`.
Score >= 80: CERTIFIED. Score < 80: FAILED.

## Coverage Heuristic

- `scripts/foo.sh` matches `tests/**/test-foo.bats` or `tests/**/test_foo.bats`
- Scripts in `scripts/` are MANDATORY test targets
- Skills and agents are OPTIONAL (reported but not blocking)

## CI Integration

`ci-test-quality-gate.sh` runs in the `bats-tests` job:
1. Run `test-auditor.sh --all --json`
2. Check all scores >= 80
3. Run `test-coverage-checker.sh`
4. Exit 1 if any test fails quality or mandatory scripts lack tests

## Files

| File | Max lines | Purpose |
|------|-----------|---------|
| `scripts/test-auditor.sh` | 140 | Score and certify test files |
| `scripts/test-coverage-checker.sh` | 80 | Find missing tests |
| `scripts/ci-test-quality-gate.sh` | 60 | CI gate orchestrator |
| `tests/evals/test-auditor.bats` | 150 | Tests for the auditor itself |

## Non-Goals

- LLM-based analysis (must be deterministic)
- Modifying test content (only reads and scores)
- Replacing `audit-test-quality.sh` (complementary, not replacement)

## References

- `scripts/audit-test-quality.sh` — Existing L0-L3 classifier
- `docs/propuestas/SPEC-043-responsibility-judge.md` — Hook quality pattern
- `docs/rules/domain/verification-before-done.md` — Rule #22
- `docs/rules/domain/pre-commit-bats.md` — BATS before commit

## Resolution (2026-04-25)

**Status drift correction.** SPEC-055 was effectively implemented across multiple Era 186 batches but the spec status was never flipped. Verification on 2026-04-25 confirmed all 4 deliverable scripts and the auditor self-test exist and pass:

### Files delivered

- `scripts/test-auditor.sh` — Score and certify test files (CLI: `--all`, `--json`, single-file)
- `scripts/test-auditor-engine.py` — 9-criteria scorer (c1_exists, c2_safety, c3_positive, c4_negative, c5_edge, c6_isolation, c7_coverage, c8_spec, c9_assertions)
- `scripts/test-coverage-checker.sh` — Find missing tests for scripts/ targets
- `scripts/ci-test-quality-gate.sh` — CI gate orchestrator
- `scripts/test-auditor-sweep.sh` — Global sweep with ranking + bottom-N (SE-039)
- `tests/evals/test-auditor.bats` — Self-test (15 tests, certified score 83)

### Coverage verification

- Daily use: every batch in Era 186 (43 batches) ran `bash scripts/test-auditor.sh tests/X.bats` to verify ≥80 score before commit
- Sweep verification: 329/329 BATS files compliant (≥80) as of 2026-04-25 — 100% baseline
- Bug fix bundled: sweep was reading `.score` (non-existent) instead of `.total` (correct field). Repaired in same commit; sweep now correctly reports compliance

### Acceptance criteria final

- [x] Deterministic 9-criteria scorer with hash certification
- [x] CI integration via `ci-test-quality-gate.sh`
- [x] Coverage heuristic for scripts/*.sh → tests/test-*.bats matching
- [x] Score ≥80 = CERTIFIED, Score <80 = FAILED
- [x] No LLM calls (deterministic)

### Era

Implemented across Era 182-186 (2026-04-20 to 2026-04-25). Used by every test in batches 5-51 of pm-workspace.
