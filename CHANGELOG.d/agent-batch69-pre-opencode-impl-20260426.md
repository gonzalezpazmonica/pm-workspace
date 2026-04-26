## [6.20.0] — 2026-04-26

Batch 69 — Pre-OpenCode implementation sprint — SE-079 + SE-080 + SE-074 Slice 3 IMPLEMENTED en un único PR. Cierra todo lo que quedaba ANTES del replatform a OpenCode (SE-077/SE-078).

### Added (SE-079 — pr-plan G13 scope-trace gate)
- `scripts/pr-plan-gates.sh::g13_scope_trace` — nueva gate. Cada archivo cambiado en un PR debe trazar a (a) un AC del spec referenciado por token overlap o path hint, (b) la whitelist hard-coded (`CHANGELOG.md`, `CHANGELOG.d/`, `.scm/`, `.confidentiality-signature`, `.pr-summary.md`, el propio spec), o (c) un override `Scope-trace: skip — <razón ≥10 chars>` en `.pr-summary.md`. Heurística pure-bash, zero LLM calls. Soft-skip cuando no hay spec ref detectable.
- `scripts/pr-plan.sh` — registro `gate "G13" "Scope-trace audit" g13_scope_trace`.
- `tests/structure/test-pr-plan-g13-scope-trace.bats` — 23 tests, score 86 certificado. Cubre: skip si no hay diff, WARN si origin/main inalcanzable, WARN si no hay spec ref, FAIL con NO MATCH para archivos huérfanos, override aceptado/rechazado por longitud, edge cases (branch name fallback, ACs vacíos, mixed-case, tokens cortos).
- Output del gate en éxito: `B8 attention-anchor present (<spec_id>)` — pareado con SE-080.

### Added (SE-080 — attention-anchor vocabulary)
- `docs/rules/domain/attention-anchor.md` — 75 líneas. Define los 4 patterns Genesis (B8 ATTENTION ANCHOR, B9 GOAL STEWARD, A7 ADVERSARIAL REVIEW, A9 SUPERVISED EXECUTION) con su mapeo a primitives ya implementados en pm-workspace. Cita el repo upstream `danielmeppiel/genesis` por URL. Hard NO list explícito: no porta R-tier ni A1-A6, no agente "genesis-architect", no `apm`/`npx` distribution.
- 4 cross-references unilíneas en `radical-honesty.md`, `autonomous-safety.md`, `code-review-court.md` y `SE-079` spec — todos los host files se mantienen ≤150 líneas tras la anotación.
- `tests/structure/test-attention-anchor-vocabulary.bats` — 22 tests, score 87 certificado. Verifica que el doc cita el upstream por URL, define los 4 nombres, mapea cada uno a su primitive, no inventa agentes/skills nuevos, no introduce R-tier, y cada cross-ref sigue intacto.

### Added (SE-074 Slice 3 — resource isolation hardening)
- `scripts/parallel-specs-db-sandbox.sh` — DB sandbox per-worker. Subcomandos `init` / `path` / `destroy` / `list`. SQLite default (zero-config), Postgres opt-in via `SPEC_DB_BACKEND=postgres` + `SPEC_DB_PG_ADMIN_URL` + `SPEC_DB_PG_TEMPLATE`. `init` emite una línea `DATABASE_URL=…` que el orchestrator `eval`-ea para exportarla al worker (12-factor). Validación estricta de `worktree_name` (regex `[a-zA-Z0-9._-]+`, max 100 chars) — rechaza shell metachars, path traversal, dollar/backtick.
- `scripts/parallel-specs-cleanup-stale.sh` — cleanup de worktrees inactivos. List-mode default (cron-safe), `prune --confirm` requerido para destruir. Refusal gates: uncommitted changes, commits ahead de main sin upstream, sentinel `.do-not-clean`, pidfile activo, paths fuera de `WORKTREES_DIR`. Foot-gun guard: `--threshold-hours` rechaza < 1h o no-numérico.
- `scripts/parallel-specs-orchestrator.sh` — patch mínimo (3 líneas init + 4 líneas destroy) para integrar el DB sandbox en spawn/cleanup. Best-effort — fallo del sandbox NO mata al worker.
- `tests/structure/test-parallel-specs-db-sandbox.bats` — 21 tests, score 88 certificado.
- `tests/structure/test-parallel-specs-cleanup-stale.bats` — 19 tests, score 83 certificado.

### Acceptance criteria cumplidos
- ✅ AC-10/AC-11 (Slice 2 — ya en main vía PR #710)
- ✅ AC-12 DB sandbox per-worktree (SQLite default, Postgres opt-in)
- ✅ AC-13 Cleanup hook async stale worktrees (list-mode default + --confirm gating)
- 🔵 AC-14 (deferred) Network namespace isolation — opt-in, requiere root, fuera de Slice 3 v1

### Spec frontmatter
SE-074: `effort:` actualizado para reflejar Slices 1+1.5+2+3 IMPLEMENTED. Slice 3 ACs marcados `[x]` con path al script.

### Updated
- `docs/rules/domain/parallel-spec-execution.md` — sección "DB sandbox + cleanup (Slice 3)" añadida; pre-requisitos compactados; ≤150 líneas.

### Tests acumulados
85 tests nuevos / 4 ficheros, todos certificados ≥80 (G13: 86, attention-anchor: 87, db-sandbox: 88, cleanup-stale: 83). 28/28 orchestrator + 32/32 merge-queue + 18/18 adaptive-halting siguen verdes (sin regresiones).

### Why en una sola PR
Solicitud explícita de la usuaria: "Sigue implementando para una sola pr lo que nos falte antes del opencode replatform. Necesitamos migrar a OpenCode cuanto antes". Trade-off PR grande (≈1500 LOC) vs. desbloquear SE-077/SE-078 sin esperar 3 ciclos de review.

### Pattern alignment (Genesis B8/B9/A7/A9)
SE-080 nombra los 4 patterns que ya implementábamos:
- B8 ATTENTION ANCHOR → SE-074 worker spawn (`SPEC_WORKER_ID`) + G11 + G13 emite el marker
- B9 GOAL STEWARD → `radical-honesty.md` Rule #24 + G13 enforces
- A7 ADVERSARIAL REVIEW → Code Review Court (5 jueces, SPEC-124)
- A9 SUPERVISED EXECUTION → `autonomous-safety.md` (AUTONOMOUS_REVIEWER, draft PRs, agent/* branches)
