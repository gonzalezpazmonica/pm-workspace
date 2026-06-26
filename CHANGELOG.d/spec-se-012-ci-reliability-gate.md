# SPEC-SE-012 — Signal/Noise CI Reliability Gate

**Date:** 2026-06-24

## SPEC-SE-012 — Signal/Noise Reduction: CI Reliability Gate

El bug del matcher LLM ya estaba resuelto. Este entry completa el módulo de
CI pre-push reliability check.

### scripts/ci-reliability-gate.sh (new)

Script de detección pre-push de causas frecuentes de fallo CI:
- Check 1 empty-dirs: directorios vacíos que git no trackea
- Check 2 staged-gitignored: ficheros en .gitignore staged por error
- Check 3 exec-permissions: .sh files sin bit de ejecución
- Check 4 broken-symlinks: symlinks que apuntan a targets inexistentes
- Check 5 large-files: ficheros >5MB (alerta LFS)
- Check 6 encoding: ficheros .py/.ts/.sh con encoding no-UTF8
- Check 7 trailing-ws-bats: trailing whitespace en .bats (rompe tests)
- Check 8 tabs-python: tabulaciones como indentación en Python
- Flag --json: output JSON con checks array y all_passed bool
- Flag --fix-empty-dirs: crea .gitkeep en dirs vacíos detectados
- Bounded find calls (maxdepth + FIND_PRUNE_ARGS) para performance

### scripts/pr-plan-gates.sh: g_pre_push_reliability()

Nueva función gate G15 (advisory, no bloqueante):
- Llama a ci-reliability-gate.sh --json
- Emite WARN con lista de checks fallidos — nunca FAIL
- Degradación graceful si ci-reliability-gate.sh no existe

### scripts/pr-plan.sh: Gate G15

Nuevo gate G15 "CI reliability (advisory)" añadido al pipeline de pr-plan.

### tests/bats/test-spec-se-012-ci-gate.bats (new)

10 tests BATS — todos PASS:
- Script existe y es ejecutable
- --json produce JSON válido
- all_passed field presente y booleano
- checks array tiene >= 5 elementos (tiene 8)
- Cada check tiene name, passed, details
- Los 8 check names esperados presentes
- Salida human-readable sin --json
- --fix-empty-dirs crea .gitkeep en dir vacío
- g_pre_push_reliability definida en pr-plan-gates.sh
- G15 wired en pr-plan.sh
