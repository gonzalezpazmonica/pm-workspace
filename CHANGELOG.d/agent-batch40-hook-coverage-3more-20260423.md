# Batch 40 — Hook coverage +3: ast-comprehend, agent-dispatch, stop-memory-extract

**Date:** 2026-04-23
**Version:** 5.84.0

## Summary

Continuación del ratchet iniciado en batch 39. Cobertura hooks subida 21/58 (36%) a 24/58 (41%). Tests para los siguientes 3 hooks más grandes sin coverage.

## Cambios

### A. `tests/test-ast-comprehend-hook.bats` — 25 tests certified
PreToolUse(Edit) hook que inyecta mapa estructural antes de editar. Invariante RN-COMP-02: nunca bloquea.

Cubre: empty/malformed/null inputs, skip <50 lines, MIN_LINES threshold, COMPLEXITY_WARN, CLAUDE_TOOL_INPUT_FILE_PATH env fallback, missing ast-comprehend.sh graceful exit, directory-as-file edge, isolation hook no modifica target file.

### B. `tests/test-agent-dispatch-validate.bats` — 25 tests certified
PreToolUse(Task) hook tier strict. Valida prompts de subagentes contra 5 categorias: commands/, CHANGELOG, skills/, git push/PR, rules/.

Cubre: only-Task filtering, empty/null prompt skip, 5 error categories (block), 3 warning categories (non-block), case-insensitive CHANGELOG match, multi-trigger combination, prompt_contains helper, isolation.

### C. `tests/test-stop-memory-extract.bats` — 27 tests certified
Stop hook SPEC-013v2. Extrae decisions/corrections/discoveries/references del session-hot.md + repeated failures del action-log.jsonl. Archiva action-log post-extraccion.

Cubre: 4 PHASE del extraction flow, 4 extraction categories, quality gate (x4 invocaciones), malformed JSON en action-log, binary content en session-hot, large file timeout boundary, URL dedup, special chars sanitization, always-exit-0 invariant.

### D. Ratchet actualizado

`.ci-baseline/hook-untested-count.count`: 37 a 34.

## Descubrimientos técnicos

- `agent-dispatch-validate` requiere `SAVIA_HOOK_PROFILE=strict` (tier mas alto que security)
- `stop-memory-extract` persiste en `$HOME/.claude/projects/{slug}/memory/` — tests isolan `HOME` a TMPDIR para evitar contaminar memoria real
- Quality gate (`passes_quality_gate` de memory-extract-lib) puede rechazar silent, los tests accept either outcome (file created or not)

## Validacion

- `bats tests/test-ast-comprehend-hook.bats`: 25/25 PASS
- `bats tests/test-agent-dispatch-validate.bats`: 25/25 PASS
- `bats tests/test-stop-memory-extract.bats`: 27/27 PASS
- `bash scripts/hook-test-coverage-audit.sh`: untested 37 a 34
- `scripts/readiness-check.sh`: PASS

## Progreso Era 186 hook coverage

| Batch | Tested | Untested | Cobertura |
|---|---|---|---|
| Pre-39 | 18/58 | 40 | 31% |
| Batch 39 | 21/58 | 37 | 36% |
| **Batch 40** | **24/58** | **34** | **41%** |

Proximos 5 candidatos por tamaño:
- cwd-changed-hook (104 lines)
- emotional-regulation-monitor (99 lines)
- ast-quality-gate-hook (96 lines)
- pbi-history-capture (93 lines)
- prompt-hook-commit (91 lines)

## Referencias

- Coverage audit: `scripts/hook-test-coverage-audit.sh`
- Baseline: `.ci-baseline/hook-untested-count.count`
- Batch 39 (precedent): `CHANGELOG.d/agent-batch39-hook-test-coverage-20260423.md`
