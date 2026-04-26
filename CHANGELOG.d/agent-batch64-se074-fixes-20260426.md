## [6.15.0] — 2026-04-26

Batch 64 — SE-074 post-merge fixes — corrección de 3 bugs detectados tras integrar paralelismo de specs + adaptive halting (PR #707).

### Fixed
- `scripts/parallel-specs-orchestrator.sh` — `--queue` ya no deja whitespace residual al procesar líneas con comments inline. El trim anterior (`${line## }`) sólo borraba un espacio, dejando trailing whitespace que rompía el lookup posterior de specs (`find` con patrón `"SE-140 *.md"` retornaba vacío). Reemplazado por regex greedy `^[[:space:]]*(.*[^[:space:]])[[:space:]]*$`.
- `scripts/parallel-specs-orchestrator.sh` — effort tier en minúsculas (`s`/`m`/`l`) en frontmatter de spec ya se reconoce. El `grep -oE '^[SML]'` era case-sensitive y caía al default `M`, asignando budget medio a specs grandes con lowercase.
- `scripts/adaptive-halting.sh` — exclusión de `.halt-state.prev.json` añadida al `find` que computa el tree-hash. Sin ella, el snapshot anterior contaminaba el hash actual y el criterio de convergencia nunca se estabilizaba en árboles con halting iterativo.

### Tests
- `tests/structure/test-parallel-specs-orchestrator.bats` — 3 regression tests (queue trim, lowercase tier, mixed-case normalisation). 26/26 pasan.
- `tests/structure/test-adaptive-halting.bats` — 18/18 siguen pasando con la nueva exclusión.

### Spec ref
SE-074 (`docs/propuestas/SE-074-parallel-spec-execution.md`) — IMPLEMENTED. Estos fixes no alteran ACs ni añaden funcionalidad nueva; son correcciones de comportamiento dentro del scope de Slices 1+1.5 ya entregados.
