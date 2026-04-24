# Batch 47 — Hook coverage +3: post-tool-failure-log, post-edit-lint, acm-turn-marker

**Date:** 2026-04-24
**Version:** 5.91.0

## Summary

**MILESTONE 75% ALCANZADO.** Novena iteracion ratchet. 42/58 (72%) a 45/58 (77.6%). Meta era 45/58 (75%).

## Cambios

### A. `tests/test-post-tool-failure-log.bats` — 39 tests certified (score 98)
PostToolUseFailure — SPEC-068 structured tool failure logging. Error categorization + retry hints + pattern detection.

Cubre: pass-through (empty stdin, log dir auto-created), 6 error categories (permission/EACCES, not_found/ENOENT/command not found, timeout/deadline exceeded, syntax/invalid JSON/unterminated, network/ECONNREFUSED/SSL/DNS, unknown fallback) con retry hints apropiados, log format (valid JSON line, ISO 8601 UTC timestamp, YYYY-MM-DD.jsonl filename, tool field capture, unknown tool fallback, error truncation 200 chars), pattern detection (3rd same tool = repeated, different tools no pattern, 1st = no pattern field), sanitization (double quotes to single, newlines to space), edge cases (empty error falls back to raw, 10KB input, null error field), coverage (6 categories, categorize_error function, pattern threshold).

### B. `tests/test-post-edit-lint.bats` — 37 tests certified (score 90)
PostToolUse async — multi-lang auto-lint tras edit.

Cubre: pass-through (empty file_path, no tool_input, unknown extension .xyz, no extension, binary .png), 11 language extensions (cs/py/ts/tsx/js/jsx/go/rs/rb/php/tf) con linter invocation (dotnet/ruff/eslint/gofmt/rustfmt/rubocop/php-cs-fixer/terraform), missing linter graceful skip (empty PATH), eslint local-only check (requires node_modules/.bin/eslint), jq parsing (malformed JSON silent, nested fields), negative (null file_path, nonexistent file delegated to linter), edge cases (spaces in path, uppercase .PY case-sensitive, empty file, zero-byte), coverage (command -v guards 5+, || true suppression 5+, jq usage).

### C. `tests/test-acm-turn-marker.bats` — 37 tests certified (score 93)
PostToolUse — SE-063 Slice 2 ACM enforcement chain. Crea marker cuando agente lee .agent-maps/ de un proyecto.

Cubre: pass-through (empty, non-Read tools: Edit/Write/Bash, no file_path), non-ACM paths (random file, projects/ sin .agent-maps, .agent-maps fuera de projects/), ACM triggers (INDEX.acm, nested subdirs, marker name matches project, empty marker file, multiple reads idempotent, different projects diff markers), turn ID handling (CLAUDE_TURN_ID, CLAUDE_SESSION_ID fallback, default fallback), jq missing guard, malformed JSON silent, edge cases (relative paths, deeply nested, large 5KB JSON, empty project name), coverage (acm-enforcement.sh consumer ref, sed PROJECT_NAME extraction, SE-063 propuestas ref, timeout 3 guard).

### D. Ratchet actualizado

`.ci-baseline/hook-untested-count.count`: 16 a 13.

## Validacion

- `bats tests/test-post-tool-failure-log.bats`: 39/39 PASS
- `bats tests/test-post-edit-lint.bats`: 37/37 PASS
- `bats tests/test-acm-turn-marker.bats`: 37/37 PASS
- `bash scripts/hook-test-coverage-audit.sh`: untested 16 a 13
- `scripts/readiness-check.sh`: PASS

## Progreso Era 186 hook coverage

| Batch | Tested | Untested | Cobertura |
|---|---|---|---|
| Pre-39 | 18/58 | 40 | 31% |
| Batch 46 | 42/58 | 16 | 72% |
| **Batch 47** | **45/58** | **13** | **77.6%** |

**Meta 75% (45/58) SUPERADA.** Proxima meta 85% (50/58) en 2 batches mas.

## Proximos candidatos

- bash-output-compress (58 lines)
- block-branch-switch-dirty (56 lines)
- compress-agent-output (57 lines)
- memory-prime-hook (47 lines)
- shield-autostart (45 lines)

## Mejores scores del batch

- post-tool-failure-log: **score 98** (mejor del batch 47, patterns extensos y categorization completa)
- acm-turn-marker: score 93
- post-edit-lint: score 90

## Referencias

- Coverage audit: `scripts/hook-test-coverage-audit.sh`
- Baseline: `.ci-baseline/hook-untested-count.count`
- Batches 39-46: ratchet pattern consolidado
- Era 186: target 85% (50/58) en batch 49
