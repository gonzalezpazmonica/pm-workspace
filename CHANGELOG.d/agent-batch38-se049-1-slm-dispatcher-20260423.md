# Batch 38 — SE-049 Slice 1: SLM dispatcher + shared lib scaffolding

**Date:** 2026-04-23
**Version:** 5.82.0

## Summary

SE-049 (SLM command consolidation pattern) acepta 16 scripts `slm-*.sh` con duplicacion (data-prep/dataset-prep) y discovery problematico. Slice 1 crea el dispatcher unificado `scripts/slm.sh` con routing a los scripts existentes + shared library + registry. Slice 2 (migration de logica) y Slice 3 (deprecation) quedan pendientes.

## Cambios

### A. Dispatcher `scripts/slm.sh`
Flags:
- `<subcommand> [args]` — route a script correspondiente
- `list` — enumera los 16 subcommands registrados
- `--json list` — JSON para consumo programatico
- `--help` / `-h` / `help` — ayuda con tabla de registry
- Exit codes: 0 ok / 1 child failed / 2 usage error

Usa `exec bash` para preservar args, exit code y senales del subcommand.

### B. Shared library `scripts/lib/slm-common.sh`
Helpers consistentes:
- `slm_die`, `slm_warn` — error handling
- `slm_project_root`, `slm_data_dir` — path discovery
- `SLM_REGISTRY` — mapa canonico de 16 subcommands (single source of truth)
- `slm_resolve_subcommand`, `slm_list_subcommands`, `slm_print_registry_table`

Guard contra double-source via `_SLM_COMMON_LOADED`.

### C. Registry de 16 subcommands

```
collect             -> slm-data-collect.sh
prep                -> slm-data-prep.sh
dataset-prep        -> slm-dataset-prep.sh
validate            -> slm-dataset-validate.sh
synth               -> slm-synth.sh
synth-recipe        -> slm-synth-recipe.sh
train-config        -> slm-train-config.sh
train               -> slm-train.sh
eval-harness-setup  -> slm-eval-harness-setup.sh
eval-compare        -> slm-eval-compare.sh
export-gguf         -> slm-export-gguf.sh
modelfile-gen       -> slm-modelfile-gen.sh
deploy              -> slm-deploy.sh
registry            -> slm-registry.sh
project-init        -> slm-project-init.sh
pipeline-validate   -> slm-pipeline-validate.sh
```

### D. Tests BATS

`tests/test-slm-dispatcher.bats` — 30 tests certified. Cubre:
- Existence + safety (bash -n, set -uo pipefail, SE-049 ref)
- Help variants (`--help`, `-h`, `help`, no args)
- Registry: list count, JSON validity, targets exist on disk
- Negative: unknown subcommand, unknown flag, empty string, missing lib
- Edge: `--` separator, help length limit, sort determinism, nonexistent target
- Coverage: helpers defined, registry declared
- Isolation: no modification of scripts/ during help/list, exit codes bounded

### E. Documentation canonica

`docs/rules/domain/slm-consolidation-pattern.md`:
- Problema, pattern, slicing (3 slices definidos)
- Usage examples antes/despues
- Extension guide (como anadir nuevo subcommand)
- Cuando NO usar (anti-guide)

## Acceptance criteria (Slice 1)

- [x] `scripts/slm.sh` ejecutable con `--help`, `--json`, exit codes 0/1/2
- [x] `scripts/lib/slm-common.sh` shared helpers + registry
- [x] Tests BATS con isolation guards (read-only, 0 side effects en repo)
- [x] Doc canonica en `docs/rules/domain/` (<=150 lineas)

## Validacion

- `bats tests/test-slm-dispatcher.bats`: 30/30 PASS
- `scripts/readiness-check.sh`: PASS
- SE-049 status: PROPOSED a IN_PROGRESS (slices_complete: [1])

## Pendiente

- **Slice 2** migracion de logica: mover `slm-*.sh` contents a funciones `cmd_<subcommand>` en `slm.sh`. Consolidar data-prep/dataset-prep duplicadas.
- **Slice 3** deprecation: `slm-*.sh` originales emiten warning, luego se eliminan tras 1 sprint.

## Referencias

- Spec: `docs/propuestas/SE-049-slm-command-consolidation-pattern-slm-sh.md`
- Pattern doc: `docs/rules/domain/slm-consolidation-pattern.md`
- Audit origen: `output/audit-arquitectura-20260420.md` §D18
