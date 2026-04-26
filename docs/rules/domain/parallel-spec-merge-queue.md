# Regla: Parallel Spec Merge Queue

> Coordina el orden de merge de las branches producidas por `parallel-specs-orchestrator.sh`. Operativo desde Slice 2 de SE-074. NUNCA mergea, NUNCA hace push, NUNCA force.

## Cuándo usar

- Tienes ≥2 branches `agent/...` derivadas de paralelismo de specs (SE-074 Slice 1)
- Quieres rebases en cascada deterministas tras cada merge humano

## Cuándo NO usar

- Branches con cambios no-CHANGELOG en archivos compartidos → resolución humana
- PRs sin pasar por `pr-plan` antes (la cola asume PRs verdes localmente)

## Comandos

```bash
# Encolar branches según orden de finalización
bash scripts/parallel-specs-merge-queue.sh add agent/se-073-slice1-...
bash scripts/parallel-specs-merge-queue.sh add agent/se-076-slice1-...

# Ver estado de cada branch (ready / needs-rebase / merged / missing)
bash scripts/parallel-specs-merge-queue.sh list
bash scripts/parallel-specs-merge-queue.sh status

# Tras un merge en main, rebase la siguiente con auto-resolve CHANGELOG
bash scripts/parallel-specs-merge-queue.sh rebase-next

# Rebase explícito de una branch concreta
bash scripts/parallel-specs-merge-queue.sh rebase agent/se-076-slice1-...

# Drop branch de la cola (idempotente)
bash scripts/parallel-specs-merge-queue.sh remove agent/se-073-slice1-...

# Vaciar cola (requiere --confirm)
bash scripts/parallel-specs-merge-queue.sh clear --confirm
```

## Auto-resolve scope

El cascade-rebase resuelve automáticamente conflictos cuyos archivos están TODOS dentro de:

- `CHANGELOG.md`
- `CHANGELOG.d/`

La resolución es siempre `--ours` (la versión upstream, es decir main + commits ya replayed). El hook post-merge `changelog-consolidate-if-needed.sh` regenera el archivo final.

## Escalación obligatoria

Cualquier conflicto fuera del scope anterior dispara `git rebase --abort` y deja el árbol limpio. Output a stderr:

```
ESCALATE: non-CHANGELOG conflicts on agent/foo:
  src/auth/middleware.ts
  tests/integration/login.bats
```

La usuaria resuelve manualmente. Sin shortcuts.

## Configuración (env vars)

| Variable | Default | Descripción |
|---|---|---|
| `QUEUE_FILE` | `.claude/parallel-merge-queue` | Archivo plano, una branch por línea |
| `MAIN_BRANCH` | `main` | Rama base |
| `MAX_REBASE_STEPS` | 30 | Guard rail anti-loop en cascade-rebase |

## Garantías de seguridad (autonomous-safety)

- ❌ NO ejecuta `git push`
- ❌ NO ejecuta `gh pr merge` ni equivalente
- ❌ NO ejecuta `git push --force`
- ❌ NO auto-resuelve un conflicto fuera de `CHANGELOG.*`
- ✅ Se niega a operar con working tree dirty (`git status --porcelain`)
- ✅ `MAX_REBASE_STEPS` corta cualquier loop patológico
- ✅ Vuelve a la rama original tras escalación

## Referencias

- SE-074 Slice 2 spec — `docs/propuestas/SE-074-parallel-spec-execution.md`
- `feedback_changelog_cascade_rebase` (auto-memory) — patrón ya conocido pre-Slice 2
- `docs/rules/domain/autonomous-safety.md` — gates inviolables
- `docs/rules/domain/parallel-spec-execution.md` — orquestador (Slice 1+1.5)
- `scripts/parallel-specs-merge-queue.sh` — implementación
