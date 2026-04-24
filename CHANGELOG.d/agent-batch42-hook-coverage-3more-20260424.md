# Batch 42 — Hook coverage +3: pbi-history-capture, prompt-hook-commit, agent-hook-premerge

**Date:** 2026-04-24
**Version:** 5.86.0

## Summary

Cuarta iteracion ratchet. 27/58 (47%) a 30/58 (52%). Tres hooks cubiertos, todos en rangos 80-90+ lines con logica no trivial (git state, frontmatter diff, security checks).

## Cambios

### A. `tests/test-pbi-history-capture.bats` — 28 tests certified
PostToolUse(Edit|Write) — captura cambios en frontmatter de PBI en `## Historial`.

Cubre: guard only-PBI files, new PBI creation path (_created entry + updated: field), field change detection (priority, state, multiple fields), no-op when zero changes, author extraction via active-user.md slug + @system fallback, path field alternative (Write tool), outside-git graceful, quoted strings, duplicate Historial prevention, tags field tracking, coverage 11 tracked fields + extract_field helper.

### B. `tests/test-prompt-hook-commit.bats` — 29 tests certified
Semantic validation de commit messages vs staged diff. Heuristics deterministicos.

Cubre: PROMPT_HOOKS_ENABLED disable, non-git-commit skip, empty diff skip, fix-with-only-adds heuristic, add-with-only-deletes heuristic, too-short message (<10 chars), >72 char line, 3 modes (warning/soft-block/hard-block), default mode warning, CHANGELOG validator integration, clean messages pass silently, single-quoted messages parsed, unknown mode fails graceful, isolation.

### C. `tests/test-agent-hook-premerge.bats` — 32 tests certified
Pre-merge security + quality gate. 4 check categories, deterministic (no LLM).

Cubre: AGENT_HOOKS_ENABLED disable, non-merge command skip, 3 secret patterns (AWS key, GitHub PAT, private key), bare shortcut marker detection with AB#0 exempt clause, merge conflict markers, 150-line limit on .claude/agents/, .claude/skills/, .claude/commands/, .claude/rules/, docs/rules/, 3 modes, gh pr merge trigger, edge cases.

### D. Ratchet actualizado

`.ci-baseline/hook-untested-count.count`: 31 a 28.

## Patron recurrente descubierto

Tests que invocan el hook en un TEST_REPO git deben usar `HOOK_ABS="$(pwd)/$HOOK"` ANTES de `cd`. El pattern previo `(cd && run bash $HOOK)` fallaba porque `$HOOK` es relativo. El nuevo pattern:
```bash
local HOOK_ABS="$(pwd)/$HOOK"
cd "$TEST_REPO"
run bash "$HOOK_ABS" ...
cd "$BATS_TEST_DIRNAME/.."
```

Scrambled pattern: para testear deteccion de shortcut markers (AB#0 exempt) sin tripping S-06 en el propio test file, construir el marker via `p1="TO" p2="DO"; printf "%s%s" "$p1" "$p2"`.

## Validacion

- `bats tests/test-pbi-history-capture.bats`: 28/28 PASS
- `bats tests/test-prompt-hook-commit.bats`: 29/29 PASS
- `bats tests/test-agent-hook-premerge.bats`: 32/32 PASS
- `bash scripts/hook-test-coverage-audit.sh`: untested 31 a 28
- `scripts/readiness-check.sh`: PASS

## Progreso Era 186 hook coverage

| Batch | Tested | Untested | Cobertura |
|---|---|---|---|
| Pre-39 | 18/58 | 40 | 31% |
| Batch 39 | 21/58 | 37 | 36% |
| Batch 40 | 24/58 | 34 | 41% |
| Batch 41 | 27/58 | 31 | 47% |
| **Batch 42** | **30/58** | **28** | **52%** |

**Milestone: 50%+ cruzado.** A ritmo de +3/batch, 5 batches mas para llegar a 75% (44/58).

## Proximos candidatos

- post-report-write (83 lines)
- agent-tool-call-validate (81 lines)
- stress-awareness-nudge (78 lines)
- competence-tracker (76 lines)
- memory-auto-capture (74 lines)

## Referencias

- Coverage audit: `scripts/hook-test-coverage-audit.sh`
- Baseline: `.ci-baseline/hook-untested-count.count`
- Batches 39-41: ratchet pattern consolidado
