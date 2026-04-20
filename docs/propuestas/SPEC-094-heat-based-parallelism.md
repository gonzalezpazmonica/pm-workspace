---
spec_id: SPEC-094
title: Heat-Based Lightweight Parallelism for Dev Sessions
status: IMPLEMENTED
origin: Anvil research (ppazosp/anvil, 2026-04-08)
severity: Media
effort: ~2h
---

# SPEC-094: Heat-Based Lightweight Parallelism

## Problema

`dag-scheduling` es potente pero complejo para proyectos pequeños. Un spec
con 5 slices donde 2-3 son independientes no justifica un grafo completo.
Los devs necesitan una forma ligera de marcar "estos slices pueden ir en
paralelo" sin construir un DAG formal.

Inspirado en Anvil (ppazosp/anvil): "heats" agrupan issues en workstreams
dentro de una fase. Fases = secuencia, heats = paralelo dentro de la fase.

## Solución

Script `scripts/heat-scheduler.sh` que:

1. Lee un plan de slices (JSON) con campo opcional `heat`
2. Agrupa slices por fase (order) y heat (parallelism within phase)
3. Genera waves ejecutables: slices del mismo heat en la misma wave
4. Valida que no haya conflictos de ficheros entre heats paralelos
5. Output: wave-plan JSON compatible con wave-executor.sh

### Formato de entrada

```json
{
  "slices": [
    {"id": 1, "name": "Domain entities", "phase": 1, "heat": "core", "files": ["Sala.cs"]},
    {"id": 2, "name": "Repository", "phase": 1, "heat": "data", "files": ["SalaRepo.cs"]},
    {"id": 3, "name": "Controller", "phase": 2, "heat": "api", "files": ["SalaCtrl.cs"]},
    {"id": 4, "name": "Unit tests", "phase": 3, "heat": "test-unit", "files": ["SalaTests.cs"]},
    {"id": 5, "name": "Integration tests", "phase": 3, "heat": "test-int", "files": ["SalaIntTests.cs"]}
  ]
}
```

Phase 1: slices 1+2 run in parallel (different heats, no file conflict).
Phase 2: slice 3 runs alone.
Phase 3: slices 4+5 run in parallel.

### Formato de salida

Wave-plan JSON compatible with `wave-executor.sh`:

```json
{
  "waves": [
    {"wave": 1, "tasks": [{"id": "1", "heat": "core"}, {"id": "2", "heat": "data"}]},
    {"wave": 2, "tasks": [{"id": "3", "heat": "api"}]},
    {"wave": 3, "tasks": [{"id": "4", "heat": "test-unit"}, {"id": "5", "heat": "test-int"}]}
  ],
  "total_waves": 3,
  "max_parallel": 2,
  "file_conflicts": []
}
```

## Integración con dev-session

En `/dev-session start`, si `dev-orchestrator` detecta slices independientes:
- Asignar heats automáticamente por análisis de ficheros target
- Ofrecer modo `--parallel` que usa heat-scheduler en vez de serial
- Mantener serial como default (backwards compatible)

## Criterios de aceptación

- [ ] Script `scripts/heat-scheduler.sh` con plan/validate/conflicts subcomandos
- [ ] Detecta conflictos de ficheros entre heats del mismo phase
- [ ] Output compatible con wave-executor.sh
- [ ] Modo degradado: sin heats → serial (1 slice por wave)
- [ ] Tests BATS >= 12 casos
