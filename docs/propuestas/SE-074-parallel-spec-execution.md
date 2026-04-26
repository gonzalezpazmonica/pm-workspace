---
id: SE-074
title: SE-074 — Parallel spec execution con worktrees + bounded concurrency
status: IMPLEMENTED
origin: Cole Medin Linkedin post 2026-04-25 + post Era 187 capacity assessment
author: Savia
priority: alta
effort: M 8h (Slice 1) + S 3h (Slice 1.5) + S 4h (Slice 2) + M 6h (Slice 3) | Slices 1+1.5+2+3 IMPLEMENTED 2026-04-26
related: bounded-concurrency, autonomous-safety, pr-plan, code-review-court
approved_at: "2026-04-26"
applied_at: "2026-04-26"
expires: "2026-06-26"
era: 188
---

# SE-074 — Parallel spec execution

## Why

Savia hoy ejecuta UN spec a la vez. Con 100% hook coverage, CI fiable y SDD maduro, el cuello de botella ya no es la calidad — es el throughput secuencial. Cole Medin (LinkedIn 2026-04-25) describe un patrón de 5 sesiones Claude Code paralelas que va en la dirección correcta, pero sólo funciona si la infraestructura subyacente impide colisiones.

Savia tiene esa infraestructura (hooks, gates, ratchet, signed audits, CHANGELOG cascade fix). Falta el orquestador.

Cost of inaction: el usuario sigue siendo el bottleneck (mergea PRs uno a uno). Cada PR es ~30min de espera CI. Con 5 specs en paralelo, throughput pasa de 1 PR/30min a 5 PRs/30-40min (no 5x lineal por overhead de coordinación, pero sí 3-4x real).

## Scope

### Slice 1 (M, 8h) — Worktree manager + spec queue

`scripts/parallel-specs-orchestrator.sh`:

- **Input**: lista de spec IDs (e.g. `SE-073 SE-072 SPEC-080`) o archivo `.parallel-queue.txt`
- **Output**: 1 worktree por spec en `.claude/worktrees/spec-<ID>-<timestamp>/`
- **Per-worktree**: copia branch base, instala deps si las hay, ejecuta `/sdd-implement <spec-id>` en sesión Claude Code separada
- **Concurrency cap**: `MAX_PARALLEL_SPECS` (default 3, hard cap 5) per `feedback_bounded_concurrency`
- **Resource isolation**:
  - Port range derivado de hash(worktree_name): cada worktree opera en `[8080+offset, 8089+offset]` para evitar colisiones de bridge/proxy
  - Tmp dir aislado: `/tmp/savia-<worktree>/`
  - DB sandbox: SQLite per-worktree o Postgres branching (Slice 3)

### Slice 1.5 (S, 3h) — Adaptive halting + dynamic retry budget

Inspirado en Kohli et al. 2026 ("Loop, Think, & Generalize", arXiv:2604.07822). Aunque el paper trata de transformers recurrentes en profundidad, dos patrones transfieren a orquestación de specs:

**Adaptive halting con doble criterio**:
- Worker NO declara `done` solo porque tests pasen una vez
- Doble criterio para halting: **convergencia** (código sin cambios entre 2 iteraciones consecutivas) + **confianza** (tests pass + judge consensus ≥ umbral configurable, default 0.75)
- Evita PRs flaky de specs que el worker declaró completos prematuramente

**Dynamic retry budget vía Poisson clipped**:
- En lugar de `AGENT_MAX_CONSECUTIVE_FAILURES = 3` fijo
- Budget(spec) = `clip(Poisson(λ_spec), R_min=2, R_max=8)`
- λ_spec derivado del effort field del frontmatter: S→λ=2, M→λ=3, L→λ=5
- Specs L tienen más reintentos sin que specs S consuman recursos innecesariamente
- Sumado a `AGENT_TASK_TIMEOUT_MINUTES`, da control de coste granular

**Overthinking guard rail (refuerzo de policy existente)**:
- El paper aporta evidencia empírica para `AGENT_MAX_CONSECUTIVE_FAILURES`: más iteraciones ≠ mejor resultado
- Cita en spec referencia el paper como justificación de la policy

**Implementación**:

`scripts/adaptive-halting.sh`:
- Función `should_halt(worktree)`: devuelve 0 si convergencia + confianza, 1 si seguir
- Lee `.confidence-score.json` que worker actualiza por iteración (judge consensus + test pass rate)
- Hash del árbol de archivos para detectar convergencia (no cambios entre iteraciones)

`scripts/spec-budget.sh effort_to_budget <S|M|L>`:
- Devuelve N según Poisson(λ) clipped
- Usado por orquestador antes de lanzar worker

### Slice 2 (S, 4h) — Coordinación PR queue

`scripts/parallel-specs-merge-queue.sh`:

- Tras pr-plan green en cada worktree, encola PR en orden FIFO de finalización
- Aplica el patrón cascade-rebase ya documentado en `feedback_changelog_cascade_rebase`: cada merge dispara rebase del siguiente
- Si rebase falla por conflicto no-CHANGELOG → escala a la usuaria (autonomous-safety: NUNCA auto-resolve conflictos no triviales)

### Slice 3 (M, 6h) — Resource isolation hardening

- DB branching real (Postgres `CREATE DATABASE LIKE template` o Neon-style branches)
- Network namespace isolation por worktree (opt-in, requiere root)
- Cleanup automático de worktrees stale (>24h sin actividad)

## Acceptance criteria

### Slice 1
- [ ] AC-01 `scripts/parallel-specs-orchestrator.sh` acepta lista de spec IDs y crea N worktrees
- [ ] AC-02 `MAX_PARALLEL_SPECS` env var con hard cap 5 (rechaza valores mayores con mensaje)
- [ ] AC-03 Cada worktree obtiene port range único (no colisión con otros worktrees vivos)
- [ ] AC-04 Cada worktree tiene tmp dir aislado `/tmp/savia-<worktree>/`
- [ ] AC-05 Si una sesión falla, las otras continúan (graceful per-worktree failure)
- [ ] AC-06 `MAX_RUNTIME_MINUTES` (default 60) — kill sesión si excede
- [ ] AC-07 Tests BATS ≥20 score ≥80
- [ ] AC-08 Doc en `docs/rules/domain/parallel-spec-execution.md`
- [ ] AC-09 CHANGELOG entry

### Slice 1.5
- [ ] AC-09a `scripts/adaptive-halting.sh` con función `should_halt` (doble criterio: convergencia + confianza)
- [ ] AC-09b `scripts/spec-budget.sh` mapea effort field → Poisson(λ) clipped budget
- [ ] AC-09c Confidence threshold configurable vía env (default 0.75); rechazar valores fuera de [0.5, 0.95]
- [ ] AC-09d Tests BATS ≥10 score ≥80 — golden test con datos sintéticos para halting
- [ ] AC-09e Cita Kohli et al. 2026 en docstring del script + spec referenciado

### Slice 2
- [ ] AC-10 PR queue manager merge-en-orden con cascade-rebase auto-resolve para CHANGELOG
- [ ] AC-11 Conflictos no-CHANGELOG escalados (no auto-merge), notificación a la usuaria

### Slice 3
- [x] AC-12 DB sandbox per-worktree (SQLite default, Postgres opt-in) — `scripts/parallel-specs-db-sandbox.sh`
- [x] AC-13 Cleanup hook async stale worktrees — `scripts/parallel-specs-cleanup-stale.sh` (list-mode default; prune --confirm gated)
- [ ] AC-14 (deferred) Network namespace isolation por worktree — opt-in, requiere root, fuera de Slice 3 v1

## No hacen

- NO ejecuta sesiones Claude Code dentro del proceso de Savia (cada sesión es un proceso aparte, llamado vía `claude -w`)
- NO hace auto-merge de PRs (autonomous-safety vigente)
- NO bypassa AUTONOMOUS_REVIEWER bajo ningún flag

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Deps install x N worktrees agota disco | Media | Medio | Symlink a node_modules / .venv compartido si seguro |
| Memory pressure con N=5 sesiones Claude vivas | Alta | Medio | Hard cap 5, monitor RAM, default 3 |
| CI overload con 5 PRs simultáneos | Media | Bajo | GH Actions concurrency groups (ya configurado) |
| Cascade rebase no determinista | Media | Alto | Re-uso del patrón documentado en feedback memory |
| Worktrees stale acumulan disco | Alta | Bajo | Cleanup hook 24h |
| Sesión Claude se pierde sin log | Baja | Alto | Cada worktree escribe `output/parallel-runs/<id>/session.log` |

## Comparativa vs status quo

| Métrica | Hoy (secuencial) | Slice 1 (3 worktrees) | Slice 1+2 (5 worktrees) |
|---|---|---|---|
| Specs/hora | ~1 | ~2-3 | ~3-4 |
| Coste tokens | 1x | ~1.1x (overhead coordinación) | ~1.2x |
| Riesgo merge conflicts | Bajo | Medio | Alto |
| Bottleneck humano | Merges | Merges + monitoring | Merges + monitoring + conflict resolution |

## Dependencias y pre-requisitos

- ✅ Hook coverage 100% (Era 186)
- ✅ pr-plan G11 estable (PR natural-language summary, batch 58)
- ✅ Cascade rebase pattern documentado (feedback_changelog_cascade_rebase)
- ✅ Bounded concurrency rule (feedback_bounded_concurrency)
- ⚠️ Resource monitoring básico (a verificar antes de Slice 1)

## Slicing approval gate

Slice 1 NO arranca hasta que:
1. La usuaria apruebe explícitamente el spec (este doc en status APPROVED ya cumple)
2. Resource monitoring básico verificado (RAM/disco disponible para 3 sesiones simultáneas)
3. AUTONOMOUS_REVIEWER configurado (ya está)

## Referencias

- Cole Medin LinkedIn 2026-04-25 — "5 Claude Code sessions" playbook (5 pillars)
- Kohli H, Parthasarathy S, Sun H, Yao Y. (2026) "Loop, Think, & Generalize: Implicit Reasoning in Recurrent-Depth Transformers". arXiv:2604.07822v1. Adaptive halting (convergencia + confianza), dynamic Poisson-clipped iteration budget, overthinking degradation
- `feedback_bounded_concurrency` — política existente
- `feedback_changelog_cascade_rebase` — patrón ya conocido
- `docs/rules/domain/autonomous-safety.md` — gates inviolables
- Claude Code `-w` flag — soporte nativo de worktrees
- `.claude/skills/spec-driven-development/` — workflow base que se invoca per-worktree

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Worktree manager | `scripts/parallel-spec-orchestrator.sh` invoca `claude -w <path>` | invoca `opencode -w <path>` (mismo flag soportado upstream desde v1.10) |
| PR queue manager | bash + `gh` CLI | idéntico, ambos frontends comparten `gh` |
| Cascade-rebase | `scripts/cascade-rebase.sh` puro bash | idéntico |
| DB sandbox | docker-compose por worktree | idéntico |
| Resource monitor | `scripts/resource-monitor.sh` (RAM/disco) | idéntico |

### Verification protocol

- [ ] Smoke test arranca 3 sesiones OpenCode en paralelo y verifica isolación de filesystem
- [ ] Tests BATS no requieren frontend específico (puro bash + git)
- [ ] PR queue genera mismo orden con ambos frontends (test deterministic)

### Portability classification

- [x] **PURE_BASH**: orquestador es 100% bash, invoca al frontend como subprocess. La capa de paralelismo es indiferente al motor LLM. Slice 1 ya soporta cualquier comando `--cmd <binary>` configurable.
