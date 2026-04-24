# Batch 44 — Hook coverage +3: competence-tracker, memory-auto-capture, agent-trace-log

**Date:** 2026-04-24
**Version:** 5.88.0

## Summary

Sexta iteracion ratchet. 33/58 (57%) a 36/58 (62%).

## Cambios

### A. `tests/test-competence-tracker.bats` — 36 tests certified
UserPromptSubmit hook — extrae facts de competencias y las anade a log estructurado.

Cubre: skip sin env SAVIA_HOOK_PROFILE=strict, 11 categorias dominio (sprint-mgmt, sdd, architecture, security, devops, testing, reporting, product, context, team, hardware), log append JSONL, log rotation al llegar a 1000 lineas, ISO timestamp, user field desde SAVIA_ACTIVE_USER, edge cases (prompts vacios, sin categoria detectable, profile no strict).

### B. `tests/test-memory-auto-capture.bats` — 30 tests certified
PostToolUse — captura automaticamente a memory-store tras Edit/Write en paths especiales.

Cubre: skip tools no Edit/Write, rate limit 5 min, file_path desde EDITED_FILE o FILE_PATH, paths especiales (scripts/, docs/rules/, .claude/rules/, .claude/commands/, tests/), type inference (pattern para tests/, convention para rules/, discovery por defecto), concept extraction de path segments, content preview primeros 200 chars, memory-store.sh invocation, coverage rate-limit timestamp update.

Bug fix in hook: `TOOL_NAME` unbound crasheaba con `set -u`. Guard anadido: `TOOL_NAME="${TOOL_NAME:-}"`.

### C. `tests/test-agent-trace-log.bats` — 31 tests certified
PostToolUse — registra traza estructurada de invocaciones Task con token metering y budget alerts.

Cubre: skip non-Task tools, Task tracing con agent name/type, token estimation (length/4), duration seconds a ms, outcome classification (success/failure/partial con status codes y timeout >120s), budget lookup integration, budget exceeded alert con overage_pct, JSONL format con timestamp ISO 8601 UTC, traces append append-only, edge cases (empty input/output, duration 0), SPEC-AGENT-METERING reference, isolation (exit always 0).

### D. Ratchet actualizado

`.ci-baseline/hook-untested-count.count`: 25 a 22.

## Validacion

- `bats tests/test-competence-tracker.bats`: 36/36 PASS
- `bats tests/test-memory-auto-capture.bats`: 30/30 PASS
- `bats tests/test-agent-trace-log.bats`: 31/31 PASS
- `bash scripts/hook-test-coverage-audit.sh`: untested 25 a 22
- `scripts/readiness-check.sh`: PASS

## Progreso Era 186 hook coverage

| Batch | Tested | Untested | Cobertura |
|---|---|---|---|
| Pre-39 | 18/58 | 40 | 31% |
| Batch 43 | 33/58 | 25 | 57% |
| **Batch 44** | **36/58** | **22** | **62%** |

A ritmo +3/batch, 3 batches mas para 75% (45/58).

## Proximos candidatos

- tool-call-healing (72 lines)
- user-prompt-intercept (71 lines)
- session-end-memory (70 lines)
- android-adb-validate (69 lines)
- live-progress-hook (69 lines)

## Bug fixes en hooks

- `memory-auto-capture.sh`: `TOOL_NAME="${TOOL_NAME:-}"` guard contra unbound var con set -u.

## Referencias

- Coverage audit: `scripts/hook-test-coverage-audit.sh`
- Baseline: `.ci-baseline/hook-untested-count.count`
- Batches 39-43: ratchet pattern consolidado
