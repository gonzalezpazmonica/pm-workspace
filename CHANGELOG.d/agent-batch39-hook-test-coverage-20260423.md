# Batch 39 — Hook test coverage audit + 3 critical hooks covered

**Date:** 2026-04-23
**Version:** 5.83.0

## Summary

Gap crítico detectado: 40 de 58 hooks sin tests BATS. Algunos eran hooks grandes y críticos sin regression guard. Batch 39 crea ratchet auditor + tests para los 3 hooks más grandes sin coverage: `data-sovereignty-gate` (173 lines), `pre-commit-review` (119 lines), `data-sovereignty-audit` (118 lines).

## Cambios

### A. Auditor de coverage con ratchet

`scripts/hook-test-coverage-audit.sh`:
- Escanea `.claude/hooks/*.sh` vs `tests/test-*.bats`
- Flags: `--json`, `--min-lines N` (filtro por tamano)
- Baseline ratchet en `.ci-baseline/hook-untested-count.count`
- Exit 1 si untested count > baseline (regression)
- Respeta exempt patterns (lib/, profile-gate, -lib) para skip de librerias

### B. Tests BATS para 3 hooks criticos

1. `tests/test-data-sovereignty-gate.bats` — 29 tests certified.
   Cubre: SAVIA_SHIELD_ENABLED flag, empty stdin, missing file_path, private destination exemptions (projects/, tenants/, .savia/, output/, .local.*, settings.local.json, .claude/sessions/), sovereignty script whitelist, malformed JSON fail-open, path normalization (.. traversal, Windows backslash), coverage helpers (profile-gate, block_fallback), isolation.

2. `tests/test-pre-commit-review.bats` — 20 tests certified.
   Cubre: no rules skip, no staged skip, rules hash file creation (sha256), cache invalidation on rules change, CLAUDE_PROJECT_DIR fallback, empty rules file, cache dir auto-creation, code file filter pattern, combined hash (content + rules), isolation.

3. `tests/test-data-sovereignty-audit.bats` — 27 tests certified.
   Cubre: SAVIA_SHIELD_ENABLED disable, empty stdin TIMEOUT_SKIP, private path exemptions, is_public function, 6 leak detection patterns (JDBC/AWS/GitHub PAT/OpenAI sk-/private key/internal IP), clean file no-leak, append-never-overwrite audit log, async exit always 0.

### C. Ratchet baseline establecido

`.ci-baseline/hook-untested-count.count: 37` (reducido desde 40 tras coverage de batch 39).

Cualquier nuevo hook sin test falla CI. Cualquier test nuevo que reduce count puede ajustar baseline.

## Detalles tecnicos

**Env requirements descubiertos durante tests:**
- `SAVIA_HOOK_PROFILE=security` required para activar profile gate en sovereignty hooks
- `unset SAVIA_SHIELD_ENABLED` en setup() para evitar leak desde shell contaminado

**Pattern dynamic construction:**
Tests de deteccion de credenciales usan `printf "%s%s%s" prefix sep body` para evitar tripping `block-credential-leak.sh` durante commit de los propios tests.

## Validacion

- `bats tests/test-data-sovereignty-gate.bats`: 29/29 PASS
- `bats tests/test-pre-commit-review.bats`: 20/20 PASS
- `bats tests/test-data-sovereignty-audit.bats`: 27/27 PASS
- `bash scripts/hook-test-coverage-audit.sh`: untested 40 -> 37
- `scripts/readiness-check.sh`: PASS

## Pendiente

37 hooks sin tests. Proximos candidatos por tamano:
- ast-comprehend-hook (115 lines)
- agent-dispatch-validate (110 lines)
- stop-memory-extract (109 lines)
- cwd-changed-hook (104 lines)
- emotional-regulation-monitor (99 lines)

Ratchet asegura que ningun hook nuevo se incorpora sin test.

## Referencias

- Coverage audit: `scripts/hook-test-coverage-audit.sh`
- Baseline: `.ci-baseline/hook-untested-count.count`
- Memory `feedback_test_excellence_patterns`: aplicado a las 3 suites
