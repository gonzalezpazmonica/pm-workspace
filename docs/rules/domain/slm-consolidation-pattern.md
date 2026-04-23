# SLM Consolidation Pattern (SE-049)

> Pattern canonico para unificar 16 scripts `slm-*.sh` en un solo dispatcher `scripts/slm.sh` con subcommands. Slice 1 scaffolding publicado en batch 38.

## Problema que resuelve

16 scripts `slm-*.sh` con duplicacion (`slm-data-prep.sh` vs `slm-dataset-prep.sh`, patrones help/die/usage repetidos) y discovery problematico (necesitas recordar cual script usar). Cada script reimplementa: parseo de args, help, error handling, path discovery.

## Pattern

```
scripts/
├── slm.sh                    ← dispatcher (Slice 1)
├── lib/
│   └── slm-common.sh         ← shared helpers + registry (Slice 1)
└── slm-*.sh                  ← legacy scripts (deprecated en Slice 3)
```

### Dispatcher (`scripts/slm.sh`)

Responsabilidad: routing + help + list + JSON API. No contiene logica de SLM propiamente.

```bash
slm.sh <subcommand> [args...]  # route
slm.sh list                    # lista registry
slm.sh --help                  # help
slm.sh --json list             # JSON output
```

### Shared library (`scripts/lib/slm-common.sh`)

Contiene:
- `slm_die`, `slm_warn` — error handling consistente
- `slm_project_root`, `slm_data_dir` — path discovery
- `SLM_REGISTRY` — mapa canonico subcommand → target script (source of truth)
- `slm_resolve_subcommand`, `slm_list_subcommands`, `slm_print_registry_table`

### Registry (source of truth)

Declarado como `declare -gA SLM_REGISTRY=(...)` en la lib. Slice 2 migrara logica desde cada script a funciones del dispatcher usando este registry.

## Slicing

### Slice 1 (batch 38) — Scaffolding + routing
- `slm.sh` dispatcher + `lib/slm-common.sh`
- Registry de 16 subcommands (routing thin a scripts existentes)
- BATS tests ≥15 (30 certified)
- Docs canonica (este fichero)

### Slice 2 — Migration de logica
- Mover logica de cada `slm-*.sh` a funciones `cmd_<subcommand>` en `slm.sh`
- Eliminar duplicacion `data-prep` vs `dataset-prep`
- Helpers compartidos en `lib/slm-common.sh`

### Slice 3 — Deprecation
- `slm-*.sh` scripts originales emiten warning "use: slm.sh <subcommand>"
- Tras 1 sprint, scripts se eliminan
- CI guard falla si nuevo `scripts/slm-*.sh` se introduce (force pattern)

## Usage

```bash
# Antes
bash scripts/slm-data-collect.sh --source specs --output raw.jsonl

# Despues (canonical)
bash scripts/slm.sh collect --source specs --output raw.jsonl

# Discovery
bash scripts/slm.sh list       # lista 16 subcommands
bash scripts/slm.sh --help     # tabla completa
bash scripts/slm.sh --json list  # consumo programatico
```

## Extension (anadir nuevo subcommand)

1. Crear script temporal `scripts/slm-newfeature.sh` (Slice 1 routing) O funcion `cmd_newfeature` en slm.sh (Slice 2+)
2. Anadir entrada en `SLM_REGISTRY` de `lib/slm-common.sh`:
   ```bash
   [newfeature]="slm-newfeature.sh"
   ```
3. Anadir test BATS en `tests/test-slm-dispatcher.bats`

## Cuando NO usar este pattern

- Comandos con cliclos de vida diferentes (uso one-shot vs continuo)
- Scripts con dependencias muy distintas (uno Python-heavy, otro bash puro)
- < 3 scripts relacionados (overhead > beneficio)

## Referencias

- Propuesta: `docs/propuestas/SE-049-slm-command-consolidation-pattern-slm-sh*.md`
- Audit origen: `output/audit-arquitectura-20260420.md` §D18
- Batch 38 Slice 1: dispatcher + lib + tests + este doc
- Batch 39+ Slice 2: logic migration (pendiente)
