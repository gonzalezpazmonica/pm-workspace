## [6.17.0] — 2026-04-26

Batch 66 — SE-074 Slice 2 IMPLEMENTED — PR queue + cascade-rebase auto-resolve.

### Added
- `scripts/parallel-specs-merge-queue.sh` — Slice 2 core. Gestiona la cola FIFO de branches producidas por el orchestrator paralelo y aplica el patrón cascade-rebase documentado en `feedback_changelog_cascade_rebase`. Subcomandos: `add`, `remove`, `list`, `status`, `clear --confirm`, `rebase <branch>`, `rebase-next`. Auto-resolve sólo para conflictos restringidos a `CHANGELOG.md` + `CHANGELOG.d/`; cualquier otra divergencia ESCALA con `git rebase --abort` y mensaje detallado a la usuaria.
- `tests/structure/test-parallel-specs-merge-queue.bats` — 32 tests, score 88 certificado.
- Sección "Merge queue (Slice 2)" añadida a `docs/rules/domain/parallel-spec-execution.md` con comandos, scope de auto-resolve y límites de seguridad.

### Hard safety boundaries (autonomous-safety.md)
- NUNCA hace `git push`
- NUNCA hace `gh pr merge` ni equivalente
- NUNCA force-pushes
- NUNCA auto-resuelve un conflicto fuera de `CHANGELOG.md` / `CHANGELOG.d/`
- Se niega a operar con working tree dirty (vía `git status --porcelain`)
- `MAX_REBASE_STEPS` (default 30) como guard rail anti-loop

### Acceptance criteria cumplidos (Slice 2)
- ✅ AC-10 PR queue manager merge-en-orden con cascade-rebase auto-resolve para CHANGELOG
- ✅ AC-11 Conflictos no-CHANGELOG escalados (no auto-merge), output `ESCALATE: <ficheros>` por stderr

### Tests breakdown (32/32 pass, score 88)
- 3 dispatch (usage / help / unknown subcmd)
- 8 queue CRUD (add idempotente, remove idempotente, list missing/merged/ready/needs-rebase, status totales)
- 2 clear (refusal sin --confirm, success con)
- 8 rebase (branch missing, dirty tree, ya merged, ahead-only, conflicto CHANGELOG.md, fragment-only, escalación non-CHANGELOG, vuelta a rama original)
- 3 rebase-next (queue vacía, skip merged + rebase stale, no-op si ready)
- 3 safety estática (ningún `git push` o `gh pr merge`, `set -uo pipefail`, MAX_REBASE_STEPS guard)
- 3 spec ref (SE-074 Slice 2, parallel-spec-execution.md, autonomous-safety.md, cascade-rebase header)

### Spec ref
SE-074 (`docs/propuestas/SE-074-parallel-spec-execution.md`) Slice 2 → IMPLEMENTED. Quedan Slice 3 (resource isolation hardening: DB sandbox, network namespace, cleanup stale worktrees) y la actualización del frontmatter del spec para reflejar Slice 2 completo.
