---
id: SE-074
title: SE-074 — Parallel spec execution con worktrees + bounded concurrency
status: APPROVED
origin: Cole Medin Linkedin post 2026-04-25 + post Era 187 capacity assessment
author: Savia
priority: alta
effort: M 8h (Slice 1 only) | Total estimado L 18h (3 slices)
related: bounded-concurrency, autonomous-safety, pr-plan, code-review-court
approved_at: "2026-04-26"
applied_at: null
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

### Slice 2
- [ ] AC-10 PR queue manager merge-en-orden con cascade-rebase auto-resolve para CHANGELOG
- [ ] AC-11 Conflictos no-CHANGELOG escalados (no auto-merge), notificación a la usuaria

### Slice 3
- [ ] AC-12 DB sandbox per-worktree (SQLite default, Postgres opt-in)
- [ ] AC-13 Cleanup hook async stale worktrees

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
- `feedback_bounded_concurrency` — política existente
- `feedback_changelog_cascade_rebase` — patrón ya conocido
- `docs/rules/domain/autonomous-safety.md` — gates inviolables
- Claude Code `-w` flag — soporte nativo de worktrees
- `.claude/skills/spec-driven-development/` — workflow base que se invoca per-worktree
