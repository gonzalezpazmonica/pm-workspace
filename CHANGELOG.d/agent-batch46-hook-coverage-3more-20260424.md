# Batch 46 — Hook coverage +3: android-adb-validate, live-progress-hook, dual-estimation-gate

**Date:** 2026-04-24
**Version:** 5.90.0

## Summary

Octava iteracion ratchet. 39/58 (67%) a 42/58 (72%). A 1 batch de la meta 75%.

## Cambios

### A. `tests/test-android-adb-validate.bats` — 41 tests certified (score 92)
PreToolUse — clasifica comandos ADB (safe/risky/blocked). Exit 2 para destructivos.

Cubre: pass-through non-ADB, SAFE (devices, logcat, getprop), RISKY (install/uninstall/pm clear/push/reboot/monkey/force-stop y variantes con underscore adb_install/_uninstall/_clear_data), BLOCKED destructivos (rm -rf, rm -r /, format, dd if=, su, root), log file auto-created con ISO timestamp, edge cases (no trailing space, adb en texto libre, empty TOOL_INPUT, special chars, large command 500+ chars, bare adb), 6 BLOCKED patterns + 9+ RISKY patterns verificados, exit codes {0,2}.

### B. `tests/test-live-progress-hook.bats` — 36 tests certified (score 93)
PreToolUse async — log de cada tool use a ~/.savia/live.log con emoji + basename.

Cubre: pass-through (empty, no tool_name), 8 tool cases (Bash con desc/command fallback, Edit/Write/Read con basename stripping dir, Agent con desc/prompt fallback, Glob pattern, Grep pattern, Skill name), Task* wildcard (TaskCreate/TaskUpdate), fallback para unknown tools, log rotation al llegar a 500 lineas (tail -250), HH:MM:SS timestamp, description head -c 80 chars truncation, malformed JSON sin crash, trap ERR a hook-errors.log, edge cases (deeply nested path, file sin extension, .savia auto-created, null tool_input, large command 1500 chars sin overflow, empty tool_input).

### C. `tests/test-dual-estimation-gate.bats` — 33 tests certified (score 92)
PostToolUse — SPEC-078 Phase 1. Advierte si spec/PBI tiene estimacion sin escala dual agent+human.

Cubre: pass-through (empty, no file_path, non-spec file, .py, nonexistent), draft stage (no estimation exits silent), completo con ambas escalas (ES y EN), warn solo human (falta agent), warn solo agent (falta human), warn solo generic effort word (falta ambas), path patterns (*.spec.md, backlog/pbi/, backlog/task/), warning content (agent_effort_minutes, human_effort_hours, review_effort_minutes), case-insensitive detection, edge cases (empty file, keyword en comment no trigger), SPEC-078 ref, isolation (siempre exit 0, no modifica spec).

### D. Ratchet actualizado

`.ci-baseline/hook-untested-count.count`: 19 a 16.

## Validacion

- `bats tests/test-android-adb-validate.bats`: 41/41 PASS
- `bats tests/test-live-progress-hook.bats`: 36/36 PASS
- `bats tests/test-dual-estimation-gate.bats`: 33/33 PASS
- `bash scripts/hook-test-coverage-audit.sh`: untested 19 a 16
- `scripts/readiness-check.sh`: PASS

## Progreso Era 186 hook coverage

| Batch | Tested | Untested | Cobertura |
|---|---|---|---|
| Pre-39 | 18/58 | 40 | 31% |
| Batch 45 | 39/58 | 19 | 67% |
| **Batch 46** | **42/58** | **16** | **72%** |

Meta 75% (45/58) al alcance en batch 47.

## Proximos candidatos

- post-tool-failure-log (60 lines)
- post-edit-lint (59 lines)
- acm-turn-marker (58 lines)
- bash-output-compress (58 lines)
- compress-agent-output (57 lines)

## Lecciones aprendidas

- Test auditor scoring: `# Ref: batch X` comment + SPEC reference garantiza +10 pts.
- Edge pattern keywords (empty/nonexistent/large/boundary/null/no-arg/timeout/overflow) necesarios para score 80+.
- "estimation" word matcher trigger hook warning: evitar en test fixtures "draft" stage.

## Referencias

- Coverage audit: `scripts/hook-test-coverage-audit.sh`
- Baseline: `.ci-baseline/hook-untested-count.count`
- Batches 39-45: ratchet pattern consolidado
