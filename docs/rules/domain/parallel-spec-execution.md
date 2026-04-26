# Regla: Parallel Spec Execution

> Permite ejecutar N specs en paralelo via worktrees aislados, bounded concurrency 3-5, adaptive halting + Poisson-clipped retry budget. Operativo desde Slice 1+1.5 de SE-074.

## Cuándo usar

- Tienes ≥2 specs APPROVED independientes (no compartir archivos)
- Suficiente RAM/disco para N sesiones simultáneas (default 3 workers ≈ 3× RAM por sesión)
- AUTONOMOUS_REVIEWER configurado (regla autonomous-safety)

## Cuándo NO usar

- Specs con dependencias entre sí (ej. SE-077 necesita SE-078) → secuencial
- Specs que tocan los mismos archivos (conflicto inevitable) → secuencial
- Recursos limitados (cuando RAM disponible <16GB)

## Comandos

```bash
# Plan + execute
bash scripts/parallel-specs-orchestrator.sh SE-073 SE-076 SE-078

# Desde queue file
echo -e "SE-073\nSE-076\nSE-078" > .parallel-queue.txt
bash scripts/parallel-specs-orchestrator.sh --queue .parallel-queue.txt

# Solo plan, no spawn
bash scripts/parallel-specs-orchestrator.sh --dry-run SE-073 SE-076

# Custom worker command (default: claude -w {worktree} --spec {spec_id})
SPEC_WORKER_CMD='opencode -w {worktree} --spec {spec_id}' \
  bash scripts/parallel-specs-orchestrator.sh SE-073
```

### Merge queue (Slice 2)

Tras `pr-plan` verde, las branches se gestionan vía `scripts/parallel-specs-merge-queue.sh`. Ver regla dedicada en `docs/rules/domain/parallel-spec-merge-queue.md` (auto-resolve restringido a `CHANGELOG.*`, escalación obligatoria fuera de ese scope).

## Configuración (env vars)

| Variable | Default | Descripción |
|---|---|---|
| `MAX_PARALLEL_SPECS` | 3 | Workers concurrentes (hard cap 5) |
| `MAX_RUNTIME_MINUTES` | 60 | Timeout por worker, kill al exceder |
| `SPEC_WORKER_CMD` | `claude -w {worktree} --spec {spec_id}` | Comando por worker; placeholders: `{worktree}`, `{spec_id}`, `{budget}`, `{ports}` |
| `PORT_RANGE_START` | 8080 | Puerto base |
| `PORT_RANGE_SIZE` | 10 | Puertos asignados por worktree |
| `PARALLEL_RUNS_DIR` | `output/parallel-runs` | Dir de logs |
| `WORKTREES_DIR` | `.claude/worktrees` | Dir de worktrees |

## Bounded concurrency

Hard cap = 5 workers simultáneos. Política `feedback_bounded_concurrency`. Justificación:
- 5 sesiones × ~4GB RAM cada = 20GB (frontera de máquinas dev)
- 5 sesiones × throughput LLM = saturación de rate-limits API
- Aumento marginal post-3 cae por overhead de coordinación

Default 3 reflejado por experiencia operativa.

## Aislamiento por worker

Cada worker recibe: worktree git propio, tmp dir aislado (`TMPDIR` exportado), port range único derivado de hash(name), y budget de retries computado dinámicamente desde el effort field (Slice 1.5).

## Adaptive halting (Slice 1.5)

Worker debe declarar `done` solo cuando se cumplen DOS criterios simultáneamente (NO solo "tests pasan una vez"):

1. **Convergencia**: tree-hash idéntico entre 2 iteraciones (no quedan refactors pendientes)
2. **Confianza**: `confidence ≥ ADAPTIVE_HALT_CONFIDENCE` (default 0.75) AND `tests_passed = true`

El worker escribe `<worktree>/.halt-state.json` cada iteración:

```json
{
  "iter": 3,
  "tree_hash": "<sha256>",
  "confidence": 0.85,
  "tests_passed": true
}
```

El orchestrator (o el propio worker) llama `bash scripts/adaptive-halting.sh should-halt <worktree>` para decidir continuar o parar.

## Retry budget dinámico (Slice 1.5)

Reemplaza `AGENT_MAX_CONSECUTIVE_FAILURES = 3` fijo. Cada spec recibe:

```
budget(spec) = clip(Poisson(λ_effort), R_MIN=2, R_MAX=8)
```

donde `λ_effort` deriva del frontmatter `effort:` field:
- `effort: S 2h` → λ=2 → budget 2
- `effort: M 4h` → λ=3 → budget 3
- `effort: L 12h` → λ=5 → budget 5

En modo determinístico (default tests/CI: `SPEC_BUDGET_DETERMINISTIC=1`), devuelve λ directo. En producción puede activarse muestreo Poisson seedeado por hash(spec_id) → reproducible per-spec.

## Garantías de seguridad (autonomous-safety)

El orquestador respeta TODAS las reglas de `docs/rules/domain/autonomous-safety.md`:

- ❌ NO hace auto-merge de PRs producidos por workers
- ❌ NO bypassa AUTONOMOUS_REVIEWER
- ❌ NO mueve workers en main directamente — cada uno crea su rama `agent/spec-<id>-...`
- ✅ Per-worker timeout vía `MAX_RUNTIME_MINUTES`
- ✅ Per-worker session log en `output/parallel-runs/<spec_id>/session.log`
- ✅ Failure de un worker NO mata a los demás (graceful per-worker failure, AC-05)
- ✅ Hard cap 5 enforced (rechaza valores mayores en el script)

## Cleanup

- Worker tmp dirs (`/tmp/savia-...`) se borran al terminar el worker
- Worktrees git (`.claude/worktrees/spec-...`) NO se borran automáticamente — el orquestador respeta el contenido para inspección. Cleanup hardening en SE-074 Slice 3 (cleanup async stale >24h).

## Inspección post-run

```bash
# Logs
ls output/parallel-runs/
cat output/parallel-runs/SE-073/session.log

# Worktree state
cd .claude/worktrees/spec-SE-073-<timestamp>/
git status
git log --oneline -5

# Halt state si el worker integró adaptive-halting
cat .claude/worktrees/spec-SE-073-<timestamp>/.halt-state.json
```

## Pre-requisitos cumplidos

- ✅ Hook coverage 100% (Era 186)
- ✅ pr-plan G11 estable (batch 58)
- ✅ Cascade rebase pattern documentado (auto-memory feedback_changelog_cascade_rebase)
- ✅ Bounded concurrency rule (auto-memory feedback_bounded_concurrency)
- ✅ AUTONOMOUS_REVIEWER configurado (.claude/rules/pm-config.local.md)
- ⚠️ Resource monitoring básico — verificar disponibilidad RAM/disco antes de Slice 1 use real (>3 workers en paralelo)

## Referencias

- SE-074 spec — `docs/propuestas/SE-074-parallel-spec-execution.md`
- Cole Medin LinkedIn 2026-04-25 — "5 Claude Code sessions in parallel" playbook (origen)
- Kohli H, Parthasarathy S, Sun H, Yao Y. (2026) — adaptive halting + Poisson budget (arXiv:2604.07822)
- `docs/rules/domain/autonomous-safety.md` — gates inviolables
- `docs/rules/domain/bounded-concurrency.md` — política de hard cap
