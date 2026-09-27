---
version_bump: minor
section: Added
---
- SE-403: `run-benchmark.sh --execute` calcula un `selection_hash` (tareas + YAML + comandos), archiva stdout/stderr por tarea y un manifiesto de procedencia (commit, árbol sucio, versión del runner) en `~/.savia/benchmark/runs/<run_id>/`, y mantiene una frontera por selección (`frontier.json`, con `flock`; las ejecuciones con árbol sucio no entran). `--compare` compara con la frontera de la misma selección o declara `INCOMPARABLE`. `results/aggregate.json` conserva su formato; el agregado ya no depende del directorio de trabajo.
