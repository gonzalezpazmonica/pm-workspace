# Batch 50 — Hook coverage +4: instructions-tracker, file-changed-staleness, session-end-snapshot, config-reload

**Date:** 2026-04-25
**Version:** 6.1.0

## Summary

Duodecima iteracion ratchet. **+4 hooks** en una iteracion (en vez de los habituales 3). Branch off main directamente, antes de merge de PR #692 (batch 49 con +3 hooks separadamente).

## Cambios

### A. `tests/test-instructions-tracker.bats` — 27 tests certified (score 93)
InstructionsLoaded async — log de archivos de instrucciones cargados por sesion.

Cubre: pass-through (empty stdin, missing file_path), logging (file_path append, ISO timestamp, memory_type/load_reason captured, multi-invocations append, log dir auto-created), format (valid JSON, 4 fields ts/file/type/reason), negative (malformed JSON, jq missing handled via timeout 2), edge (empty/null file_path, large input 5KB, zero-byte stdin, special chars in path), coverage (jq -r usage, CLAUDE_PROJECT_DIR fallback, InstructionsLoaded event), isolation (always exit 0, only writes to output/instructions-loaded/).

### B. `tests/test-file-changed-staleness.bats` — 26 tests certified (score 90)
FileChanged async — marca code maps stale on file changes. Budget <100ms.

Cubre: pass-through (empty/missing/empty file_path), stale marker creation (.claude/.maps-stale), idempotent multi-invocations, .claude dir auto-created, perf budget <1s + timeout 1, error handling (trap ERR + hook-errors.log + touch failure tolerance), negative (malformed JSON, missing file_path field), edge (large stdin, special chars, zero-byte, null file_path), coverage (jq // empty fallback, CLAUDE_PROJECT_DIR), isolation (only touches .claude/.maps-stale).

### C. `tests/test-session-end-snapshot.bats` — 24 tests certified (score 88)
Stop hook — saves context snapshot via context-snapshot.sh delegation.

Cubre: stdin handling (drains, empty, large), snapshot delegation (SNAPSHOT_SCRIPT discovery 2-paths, save subcommand, missing handler), error handling (trap ERR, snapshot failure no crash), negative (malformed JSON, missing script), edge (no stdin pipe, HOME dir creation, SCRIPT_DIR resolution), coverage (2-path discovery, -x check executable, redirect /dev/null), isolation (always exit 0, no repo source modification).

### D. `tests/test-config-reload.bats` — 28 tests certified (score 92)
ConfigChange async — invalidates profile cache when settings change.

Cubre: pass-through (empty stdin, missing source), logging (source+file_path, ISO timestamp, log dir, multi-append), profile-cache invalidation (user_settings + local_settings remove savia-profile-cache, NOT removed on other source — verified empirically), TMPDIR fallback to ~/.savia/tmp, negative (malformed JSON, empty/null source), edge (large stdin 5KB, zero-byte, timeout 2), coverage (jq -r, ConfigChange event, 3 fields ts/source/file), isolation.

### E. Ratchet actualizado

`.ci-baseline/hook-untested-count.count`: 10 a 6 (referencia main pre-batch49).

NOTA: Este PR branchea off main directamente (no off batch 49). Si PR #692 (batch 49 +3 hooks) merges PRIMERO, la actualizacion a baseline sera: 10 a 3 (combined +7). Si este PR merges primero, batch 49 baseline pasara de 10 a 6.

Final state combined (cuando ambos PRs merged): hook coverage **55/58 = 94.8%**.

## Validacion

- `bats tests/test-instructions-tracker.bats`: 27/27 PASS (score 93)
- `bats tests/test-file-changed-staleness.bats`: 26/26 PASS (score 90)
- `bats tests/test-session-end-snapshot.bats`: 24/24 PASS (score 88)
- `bats tests/test-config-reload.bats`: 28/28 PASS (score 92)
- `bash scripts/hook-test-coverage-audit.sh`: PASS (untested 10 a 6)

## Progreso Era 186 hook coverage

| Punto | Tested | Untested | Cobertura |
|---|---|---|---|
| Pre-batch-39 | 18/58 | 40 | 31% |
| Batch 47 (75% milestone) | 45/58 | 13 | 77.6% |
| Batch 48 | 48/58 | 10 | 82.7% |
| Batch 49 (85% milestone, PR #692) | 51/58 | 7 | 87.9% |
| **Batch 50 (combined)** | **55/58** | **3** | **94.8%** |

**Meta 90% (52/58) y 95% (55/58) ambas SUPERADAS o casi.** Solo 3 hooks pendientes:
- token-tracker-middleware (38 lines)
- subagent-lifecycle (28 lines)
- task-lifecycle (27 lines)

Una iteracion mas → 100% coverage.

## Referencias

- Coverage audit: `scripts/hook-test-coverage-audit.sh`
- Baseline: `.ci-baseline/hook-untested-count.count`
- Batches 39-49: ratchet pattern consolidado
