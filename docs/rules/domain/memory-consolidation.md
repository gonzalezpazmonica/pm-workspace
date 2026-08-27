---
context_tier: L2
token_budget: 900
---

# Regla: Consolidación de memoria (SE-264)

> `memory-store.sh consolidate` — dedup + strip test/bench + stale flag.
> CRIT-001: todo local (`output/`, `~/.savia-memory/`); sin datos a cloud.

## Por qué

El índice `~/.savia-memory/auto/MEMORY.md` se infla con entradas de tests/bench
(`episode: many`, `test rebuild`, `inject-test`) y duplicados por `topic_key`,
degradando el recall y recortando entradas buenas por el soft cap (200).

## Comando

```bash
memory-store.sh consolidate [--dry-run] [--stale-days N]
```

- **Dedupe**: por `topic_key`, conserva la más reciente / de más contenido.
- **Strip**: entradas `episode|bug|pattern` con título/contendido de test/bench
  → se mueven a `output/memory-stripped/<fecha>.jsonl` (reversible).
- **Stale**: entradas sin `read_at`/`refs` y > `--stale-days` (default 90) →
  se marcan `stale: true` y se archivan en `MEMORY-ARCHIVE.md` (no se borran).
- **Protegidas**: `decision|architecture|lesson|convention|config` y entradas
  `human_authored` NUNCA se strippean (solo pueden marcarse stale).
- `--dry-run`: solo reporta `{scanned, deduped, stripped, stale, kept}`.
- Re-sincroniza el índice tras consolidar.

## Reglas

- Determinista: mismo store → mismo resultado.
- Reversible: todo lo movido queda en `output/` (gitignored).
- La tarea programada `memory-consolidation` (automation-scheduler) lo invoca
  semanalmente.

## Referencias

- Spec: `docs/specs/SE-264-memory-auto-consolidation.spec.md`
- `scripts/memory-consolidate.py` · `scripts/memory-store.sh`
