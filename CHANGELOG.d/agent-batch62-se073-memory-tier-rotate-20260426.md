## [6.13.0] — 2026-04-26

Batch 62 — SE-073 Slice 1 IMPLEMENTED — MEMORY.md L1 hard-cap tiered (Critical Path #1).

### Added
- `scripts/memory-tier-rotate.sh` — 2-tier rotation (Tier A active ≤30 entries, Tier B filename-only archive).
- `scripts/memory-access.sh` — increments `access_count` + updates `last_access` por memory file.
- `tests/structure/test-memory-tier-rotate.bats` — 24 tests, score 83 certified (test-auditor).
- `MEMORY-ARCHIVE.md` (cuando rotation produce demociones) — Tier B filename-only.

### Changed
- `docs/memory-system.md` — documenta hard-cap 30 entries Tier A + algoritmo de score (access_count + recency_bonus + pin_bonus + identity_bonus). 200-line ceiling histórico se mantiene como límite absoluto.

### Algorithm

Score = `access_count + recency_bonus(<30d=+3) + pin_bonus(true=+999) + identity_bonus(user_*=+500)`. Tied scores → mtime desc.

Garantías:
- `user_*` files (identidad foundational) NUNCA caen a Tier B
- `pin: true` files NUNCA caen a Tier B
- Recencia (<30d) actúa como tiebreaker positivo
- Default cap configurable via `MEMORY_TIER_A_CAP` env (default 30)

### Context

Critical Path #1 del roadmap reprio. Inspirado en GenericAgent L0_MetaRules pattern (cap 30 lines L1 index). Cada línea en MEMORY.md cuesta tokens en CADA turn — reducir cap a 30 amortiza linealmente la carga sostenida sin perder contenido (Tier B sigue accesible on-demand via grep).

Rotation se ejecuta manual por ahora; auto-trigger en Stop hook diferido a follow-up batch.

Version bump 6.12.0 → 6.13.0.
