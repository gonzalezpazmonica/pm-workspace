# Batch 45 — Hook coverage +3: tool-call-healing, user-prompt-intercept, session-end-memory

**Date:** 2026-04-24
**Version:** 5.89.0

## Summary

Septima iteracion ratchet. 36/58 (62%) a 39/58 (67%).

## Cambios

### A. `tests/test-tool-call-healing.bats` — 37 tests certified (score 93)
PreToolUse — valida Read/Edit/Write/Glob/Grep antes de ejecutar. Typo detection con find en parent dir.

Cubre: pass-through (tool no validado, Task, Bash, Glob/Grep sin pattern), block Read/Edit con empty file_path, block Write sin parent dir existente, block Glob/Grep sin pattern, typo detection (similar files suggested via find -maxdepth 1), edge cases (file_path con espacios, Glob patterns con braces), profile_gate standard, SPEC-141 reference, exit codes limitados {0,2}.

### B. `tests/test-user-prompt-intercept.bats` — 34 tests certified (score 87)
UserPromptSubmit — SPEC-015 context gate. Inyecta session-hot.md + active project hint en primer prompt.

Cubre: silent pass (empty, slash commands, <3 chars, 9 confirmaciones ES/EN: si/sí/no/ok/vale/claro/hecho/listo/gracias), session-hot injection con GLOBAL_STATE flag daily cache, no inject si flag ya existe, active project hint cuando CWD en projects/ con CLAUDE.md, edge cases (uppercase SI, multiline, JSON-like, malformed JSON, large input). Locale sí: `LC_ALL=C.UTF-8` explicit para comportamiento UTF-8.

### C. `tests/test-session-end-memory.bats` — 29 tests certified (score 87)
SessionEnd — SPEC-013/055 strict perf (<200ms sync target). Log sincrono rapido, worker background escribe session-hot.md.

Cubre: sync log con ISO timestamp y pid, multiple calls append, perf <1s target, worker background spawned con disown, worker escribe session-hot.md cuando hay modified files o session-actions.jsonl con failures (attempt>=2), no session-hot si repo clean y sin actions, branch name en worker log, drain stdin (empty, JSON, large), non-git repo graceful fallback, HOME auto-created, frontmatter type:session-hot, SPEC-013/055 references.

### D. Ratchet actualizado

`.ci-baseline/hook-untested-count.count`: 22 a 19.

## Validacion

- `bats tests/test-tool-call-healing.bats`: 37/37 PASS
- `bats tests/test-user-prompt-intercept.bats`: 34/34 PASS
- `bats tests/test-session-end-memory.bats`: 29/29 PASS
- `bash scripts/hook-test-coverage-audit.sh`: untested 22 a 19
- `scripts/readiness-check.sh`: PASS

## Progreso Era 186 hook coverage

| Batch | Tested | Untested | Cobertura |
|---|---|---|---|
| Pre-39 | 18/58 | 40 | 31% |
| Batch 44 | 36/58 | 22 | 62% |
| **Batch 45** | **39/58** | **19** | **67%** |

A ritmo +3/batch, 2 batches mas para 75% (45/58 en batch 47).

## Proximos candidatos

- android-adb-validate (69 lines)
- live-progress-hook (69 lines)
- dual-estimation-gate (63 lines)
- post-tool-failure-log (60 lines)
- post-edit-lint (59 lines)

## Referencias

- Coverage audit: `scripts/hook-test-coverage-audit.sh`
- Baseline: `.ci-baseline/hook-untested-count.count`
- Batches 39-44: ratchet pattern consolidado
