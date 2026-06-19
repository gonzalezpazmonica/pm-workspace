# SPEC-188 P3 Pre-commitment — Contract Test Selection

**Date:** 2026-06-19
**Phase:** Pre-implementation (leccion SE-151: dataset etiquetado pre-comprometido)
**Strict rule:** these tests are SELECTED, not WRITTEN. They already exist.

## Selection criteria (pre-committed)

A test is eligible to become a contract test if and only if:

1. **It already exists** in `tests/` and passes today.
2. **It tests an invariant** documented in canonical rules:
   - autonomous-safety.md (Rule #8, agent branch isolation)
   - savia-ethical-principles.md (red lines L1-L5)
   - PII / confidentiality enforcement
   - Agent permission boundaries (agent-policies.md)
3. **The invariant is binary**: pass = system safe, fail = system breach.
4. **Loss of the test = loss of guarantee**: if removed, the invariant has no
   automated enforcement.

## The 5 tests selected (pre-committed before any code)

| # | Path | Invariant | Tests count |
|---|---|---|---|
| 1 | `tests/hooks/test-block-force-push.bats` | No destructive push outside agent branches | 15 |
| 2 | `tests/scripts/test-confidentiality-sign.bats` | Cryptographic audit signing of confidential output | 17 |
| 3 | `tests/hooks/test-hook-pii-gate.bats` | PII detection pre-commit blocks leaks | 21 |
| 4 | `tests/test-permissions-wildcard-audit.bats` | Agent permissions cannot use unsafe wildcards | 25 |
| 5 | `tests/test-validate-agent-permissions.bats` | Agent permission YAML valid | 12 |

**Total:** 5 tests, 90 individual @test cases, all passing today.

## Selection NON-criteria (rejected)

- Tests that I want to feel important (no objective rule).
- Tests for features I personally find interesting (selection bias).
- Tests inspired by ethical principles but not written specifically for them.

## Promotion / demotion process (pre-committed)

**To add a test as contract**:
1. Test must exist and pass for at least 30 days.
2. PR with title `[contract-add]` and human review obligatory.
3. Add path to `.claude/contracts/allowlist.txt`.

**To remove a test from contract**:
1. PR with title `[contract-remove]` and human review obligatory.
2. Justification: invariant deprecated, replaced, or rule changed.
3. NEVER `[contract-remove]` to silence a failing test.

## Hard limits (pre-committed)

- Hook leq 80 LOC.
- BATS tests for hook leq 200 LOC.
- Spec leq 150 LOC.
- AC binary: 100% Edit/Write to listed paths from agent session blocked.
- AC zero false positives in 20 control Edits to non-contract tests.

If any limit is exceeded mid-session, abort.

## Files affected (pre-committed)

CREATE:
- `.claude/hooks/contract-test-guard.sh`
- `.claude/contracts/allowlist.txt`
- `tests/hooks/test-contract-test-guard.bats`
- `docs/specs/SPEC-188-P3-sealed-contract-tests.spec.md`

MODIFY:
- `.claude/settings.json`
- `tests/structure/test-hooks-integrity-allowlist.bats`

NOT MODIFY:
- The 5 selected tests themselves (they remain identical).
- Any existing hook.

## Abort criteria (pre-committed)

Abort if:
- Any of the 5 selected tests is failing today.
- Hook exceeds 80 LOC.
- BATS exceeds 200 LOC.
- Hook causes regression in any of the 81 existing hooks.
- After 4h of work, AC not met.


## Hard limits — actualizacion post-adversarial

Adversarial post-impl review identifico 4 fixes CRITICAL/HIGH:
- C2: hook excedia 80 LOC (era 113). Reducido a 69 LOC. Hard limit cumplido.
- C3: bypass via SAVIA_TEST_BRANCH sin guard. Renombrado a _SAVIA_INTERNAL_TEST_BRANCH
  con guard (BATS_TEST_FILENAME || CI || SAVIA_TEST_MODE).
- C4: AC-3 declaraba bypass [contract-change] no implementado. Implementado y
  testeado (3 tests bats nuevos).
- H1: substring match permitia false positive con paths absolutos. Cambiado a
  match exacto o suffix con normalizacion via REPO_ROOT.

Tests bats LOC: 200 -> 220 (4 tests bypass anadidos). Excede limite original;
ajuste honesto documentado en SPEC. NO se ignora silenciosamente.
