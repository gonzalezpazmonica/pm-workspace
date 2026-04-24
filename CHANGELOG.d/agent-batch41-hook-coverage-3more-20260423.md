# Batch 41 — Hook coverage +3: cwd-changed, emotional-regulation, ast-quality-gate

**Date:** 2026-04-23
**Version:** 5.85.0

## Summary

Tercera iteracion del ratchet de hook coverage. 24/58 (41%) a 27/58 (47%).

## Cambios

### A. `tests/test-cwd-changed-hook.bats` — 29 tests certified
Hook CwdChanged — auto-inyecta contexto de proyecto al entrar en `projects/*/`. Sync, exit 0 + stdout.

Cubre: skip cuando cwd fuera de projects/, cleanup de state al salir, 10 language pack detections (C#/.NET, Angular, React, TS/Node, Go, Rust, Python, Java, PHP, Ruby, Terraform), context-index detection, spec count, dedup re-entry, deep subdir project name extraction, isolation hook no modifica files.

### B. `tests/test-emotional-regulation-monitor.bats` — 24 tests certified
Stop hook — session stress assessment (Anthropic "Emotion concepts in LLMs", 2026-04-02). Persiste sessiones high-friction a memory.

Cubre: missing tracker/state skip, low friction reset, 3 level thresholds (overload score>=9, high_stress 7-8, significant_friction 5-6), boundary exactly-5 triggers persist / exactly-4 skips, MEMORY.md index update, dedup same-day, 4 event counters (retry/failure/escalation/rule_skip), tracker mock pattern.

### C. `tests/test-ast-quality-gate-hook.bats` — 26 tests certified
PostToolUse async hook — ejecuta quality gate sobre codigo editado. Advisory, never blocks.

Cubre: empty stdin skip, non-code extension skip (.md, .json), 16 source extensions (cs/vb/ts/tsx/py/go/rs/php/rb/java/tf/cob/cbl/cpy/...), graceful degradation missing gate script, malformed JSON fail-open, --advisory flag passed, latest.json alias, output/quality-gates/ directory.

### D. Ratchet actualizado

`.ci-baseline/hook-untested-count.count`: 34 a 31. Tests 3 hooks mas grandes que quedaban sin coverage.

## Validacion

- `bats tests/test-cwd-changed-hook.bats`: 29/29 PASS
- `bats tests/test-emotional-regulation-monitor.bats`: 24/24 PASS
- `bats tests/test-ast-quality-gate-hook.bats`: 26/26 PASS
- `bash scripts/hook-test-coverage-audit.sh`: untested 34 a 31
- `scripts/readiness-check.sh`: PASS

## Progreso Era 186 hook coverage

| Batch | Tested | Untested | Cobertura |
|---|---|---|---|
| Pre-39 | 18/58 | 40 | 31% |
| Batch 39 | 21/58 | 37 | 36% |
| Batch 40 | 24/58 | 34 | 41% |
| **Batch 41** | **27/58** | **31** | **47%** |

## Proximos candidatos por tamaño

- pbi-history-capture (93 lines)
- prompt-hook-commit (91 lines)
- agent-hook-premerge (90 lines)
- post-report-write (83 lines)
- agent-tool-call-validate (81 lines)

Meta implicita: coverage >= 75% (44/58) para cerrar el gap critico. Actualmente 47%, trayectoria +3 hooks/batch.

## Referencias

- Coverage audit: `scripts/hook-test-coverage-audit.sh`
- Baseline: `.ci-baseline/hook-untested-count.count`
- Batches 39, 40 (precedent): ratchet pattern establecido
