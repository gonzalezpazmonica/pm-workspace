## [6.16.0] — 2026-04-26

Batch 65 — SE-074 polish — alineación timestamp/ports plan↔spawn (deja la herramienta sin roces para empezar a usarla en serio mañana).

### Fixed
- `scripts/parallel-specs-orchestrator.sh` — el bloque `Plan per spec` mostraba puertos que no se acababan usando. La causa: la fase de plan y `spawn_worker` llamaban a `date(1)` por separado y con formatos distintos (`%Y%m%d%H%M%S` vs `%Y%m%d-%H%M%S` UTC), de modo que `allocate_ports` hashing producía dos asignaciones diferentes. Ahora se calcula un único `RUN_TS` al inicio del script y `SPEC_WORKTREE_NAMES` + `SPEC_PORTS` se rellenan una vez en la fase de validación; tanto el plan como el spawn leen de esos maps. Plan output ahora coincide con la realidad (verificado con regression test #27).

### Changed
- `scripts/parallel-specs-orchestrator.sh` — el header del plan incluye una línea `run timestamp : <RUN_TS>` para correlacionar el output con los worktrees creados en disco (`.claude/worktrees/spec-<id>-<RUN_TS>/`).

### Tests
- `tests/structure/test-parallel-specs-orchestrator.bats` — 2 regression tests añadidos:
  - `#27 plan ports match spawn ports for every spec` — corre el orchestrator real con 3 specs y verifica que cada `Plan per spec` line tenga los mismos `ports=` que la `spawned` line correspondiente.
  - `#28 plan run-timestamp line is printed` — sanity check del header.
- 28/28 pasan. 18/18 adaptive-halting + 33/33 spec-budget también pasan.

### Spec ref
SE-074 (`docs/propuestas/SE-074-parallel-spec-execution.md`) — IMPLEMENTED. Polish dentro del scope de Slices 1+1.5; ningún AC nuevo, ningún cambio de comportamiento funcional (los puertos asignados a cada spec son los mismos que antes en spawn — sólo la línea informativa del plan estaba desalineada).
