## [6.10.0] — 2026-04-26

Batch 59 — SE-074 spec creado (parallel spec execution con worktrees) + ROADMAP Era 188 reprio.

### Added
- `docs/propuestas/SE-074-parallel-spec-execution.md` — spec en status APPROVED. 3 slices: worktree manager + spec queue (M 8h), PR queue manager (S 4h), DB sandbox + cleanup (M 6h). Pre-requisitos cumplidos (hook 100%, G11, cascade-rebase pattern, bounded concurrency, AUTONOMOUS_REVIEWER). Comparativa explícita vs status quo: 3-4x throughput sobre 1.1-1.2x coste tokens.
- `docs/ROADMAP.md` Era 188 sección "Memory + Throughput foundations" con pipeline ordenado SE-072 (done) → SE-073 → SE-074. Trade-off explícito: SE-074 Slice 1 (8h) bloquea ~1 día pero break-even tras 2-3 Eras post.

### Changed
- `docs/ROADMAP.md` header bump v6.8.0 → v6.10.0 con SE-074 APPROVED listado. Backlog APPROVED reordenado para incluir SE-074 entre los sin-GPU.

### Context
Inspirado en LinkedIn post de Cole Medin (2026-04-25, "5 Claude Code sessions in parallel"). El post valida que el approach de Savia va por buen camino — los 5 pillars (issue as spec, worktrees, plan-build-validate, fresh context review, self-healing AI) ya los aplica Savia. El gap era el orquestador real de paralelismo.

SE-074 capitaliza la inversión hecha en Era 186 (hook coverage 100%) + Era 187 (spec drift + ACs) + batch 57 (verified memory) + batch 58 (PR rule). Sin esa base, paralelismo = 5x el caos. Con la base, paralelismo = 3-4x throughput real.

Pendiente confirmación de la usuaria antes de arrancar SE-074 Slice 1: el spec está APPROVED pero el dry-run de resource monitoring debe verificar RAM/disco para 3 sesiones Claude Code simultáneas.

Version bump 6.9.0 → 6.10.0 (saltamos 6.9.0 que está en PR #702 todavía sin merge — al merger #702 quedará 6.9.0 antes de 6.10.0 vía cascade rebase).

### Skipping 6.9.0 explanation

PR #702 (batch 58, en cola) bumped a 6.9.0. Este batch 59 va detrás vía cascade. Cuando #702 mergee, este branch rebase y el orden CHANGELOG quedará: 6.10.0, 6.9.0, 6.8.0, ...
