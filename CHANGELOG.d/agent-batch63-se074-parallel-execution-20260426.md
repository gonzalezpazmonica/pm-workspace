## [6.14.0] — 2026-04-26

Batch 63 — SE-074 IMPLEMENTED Slices 1 + 1.5 — paralelismo de specs + adaptive halting (Critical Path #2-3).

### Added
- `scripts/parallel-specs-orchestrator.sh` — Slice 1 core. N workers paralelos en worktrees aislados, bounded concurrency hard cap 5, port allocation determinística, tmp dir sandboxing, runtime timeout, session.log per spec.
- `scripts/spec-budget.sh` — Slice 1.5. Mapeo effort field (S/M/L) → Poisson-clipped retry budget (lambda_S=2, lambda_M=3, lambda_L=5; clipped [2, 8]). Determinístico por defecto; estocástico opt-in seedeado por hash(spec_id).
- `scripts/adaptive-halting.sh` — Slice 1.5. Doble criterio halting (convergencia tree-hash + confidence ≥ floor + tests passed). Reemplaza halting binario "tests pasan una vez".
- `docs/rules/domain/parallel-spec-execution.md` — regla canónica con configuración, garantías de seguridad, comandos.
- `tests/structure/test-parallel-specs-orchestrator.bats` — 23 tests, score 88.
- `tests/structure/test-spec-budget.bats` — 15 tests, score 85.
- `tests/structure/test-adaptive-halting.bats` — 18 tests, score 81.

### Acceptance criteria cumplidos (Slice 1)

- ✅ AC-01 orchestrator acepta lista de spec IDs y crea N worktrees
- ✅ AC-02 MAX_PARALLEL_SPECS hard cap 5 (rejects valores mayores)
- ✅ AC-03 port range único por worktree (hash determinístico)
- ✅ AC-04 tmp dir aislado por worker (`/tmp/savia-spec-<id>-<ts>/`)
- ✅ AC-05 graceful per-worker failure (1 falla, otros continúan)
- ✅ AC-06 MAX_RUNTIME_MINUTES (default 60m) con `timeout(1)`
- ✅ AC-07 Tests BATS ≥20 score ≥80 (23 tests, 88 actual)
- ✅ AC-08 Doc en docs/rules/domain/parallel-spec-execution.md
- ✅ AC-09 CHANGELOG entry (este fichero)

### Acceptance criteria cumplidos (Slice 1.5)

- ✅ AC-09a `should_halt` con doble criterio (convergencia + confianza)
- ✅ AC-09b `spec-budget` mapea effort → Poisson(lambda) clipped
- ✅ AC-09c Confidence threshold configurable, validado [0.50, 0.95]
- ✅ AC-09d Tests BATS ≥10 score ≥80 (18 + 15 = 33 tests, scores 81 y 85)
- ✅ AC-09e Cita Kohli et al. 2026 arXiv:2604.07822 en docstrings + spec

### Pendiente (Slice 2 + 3 — diferido a future batches)

- Slice 2 (S 4h): PR queue manager con cascade-rebase auto-resolve
- Slice 3 (M 6h): DB sandbox + cleanup hook async stale worktrees

### Context

Critical Path #2-3 del roadmap reprio. Cambia operación de Savia desde "1 spec a la vez" a "hasta 5 specs concurrentes". 3-4x throughput esperado en cualquier proyecto que use el orchestrator. Worker command configurable via `SPEC_WORKER_CMD` — Savia lo invoca con `claude`, OpenCode lo hará con `opencode -w` (mismo flag), funciona sin cambios para cualquier frontend.

Bounded concurrency hard cap 5 por feedback_bounded_concurrency. Default 3. Justificación: 5×4GB RAM = 20GB (frontera dev), saturación rate-limits LLM, overhead de coordinación marginal post-3.

SE-074 status flip APPROVED → IMPLEMENTED.

Version bump 6.13.0 → 6.14.0.
