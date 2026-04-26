---
id: SE-073
title: SE-073 — MEMORY.md L1 index hard-cap with 2-tier (high/low-freq)
status: IMPLEMENTED
origin: GenericAgent repo study 2026-04-25 — lsdefine/GenericAgent
author: Savia
priority: alta
effort: S 3h
related: MEMORY.md, auto-memory, memory-system.md
approved_at: "2026-04-25"
applied_at: "2026-04-26"
expires: "2026-06-25"
era: 186
---

# SE-073 — MEMORY.md L1 index hard-cap tiered

## Why

GenericAgent usa L1 index **≤30 líneas** (high-signal) con el resto comprimido en L2 (filename-only references). Razón: el índice se carga en CADA turn, tokens en L1 tienen coste recurrente brutal.

Savia hoy: `~/.claude/projects/-home-monica-claude/memory/MEMORY.md` tiene cap 200 líneas (docs/memory-system.md). Actualmente 30 entradas, una línea cada una → ~30 líneas netas. **No hay problema hoy**, pero el cap 200 invita crecimiento silencioso. Cada 100 líneas añadidas × N turns/día = coste real acumulado.

Cost of inaction: MEMORY.md crece orgánicamente hasta el cap 200. Cuando llegue, ya son 170 líneas que pagamos por turn × ~50 turns/día × ~4 tokens/line = ~34k tokens extra/día solo por índice.

## Scope (Slice 1)

Reducir cap a ≤30 líneas en MEMORY.md principal, establecer 2 tiers:

### Tier A — HIGH-FREQ (inline en MEMORY.md, ≤30 líneas)

Entradas accedidas >3 veces en últimos 30 días. Formato actual (title + 1-line hook).

### Tier B — LOW-FREQ (filename-only en MEMORY-ARCHIVE.md)

Entradas accedidas ≤3 veces o >30 días sin acceso. Solo filename listado:

```
[feedback_niche_detail.md]
[feedback_old_pattern.md]
```

El agente carga MEMORY.md (≤30 líneas), busca Tier B solo on-demand via grep o Read.

### Tier transition

- Promotion B→A: access count ≥3 en 30 días
- Demotion A→B: last_access > 30 días
- Script: `scripts/memory-tier-rotate.sh` ejecutable manual o cron

## Acceptance criteria

- [ ] AC-01 MEMORY.md hard-cap 30 líneas documentado en memory-system.md
- [ ] AC-02 MEMORY-ARCHIVE.md creado con Tier B entries
- [ ] AC-03 `scripts/memory-tier-rotate.sh` moves B↔A basado en access counter
- [ ] AC-04 `scripts/memory-store.sh` access subcommand incrementa counter
- [ ] AC-05 Tests BATS (≥12) cubriendo rotation + cap enforcement
- [ ] AC-06 Doc en memory-system.md explica 2-tier

## Design

Access counter en frontmatter de cada memory file:

```yaml
---
name: feedback_X
description: ...
type: feedback
access_count: 7
last_access: 2026-04-24
---
```

Rotation algorithm (mtime o access_count ≥3 últimos 30d en A, resto en B).

## Acceptance triage

Si la reducción a 30 líneas rompe flujos actuales (demasiada memoria Tier B), abortar y reportar qué entries causan fricción. No es irrecuperable — se puede ampliar a 50 líneas si justifica.

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Agente pierde contexto importante en Tier B | Media | Alto | Access tracking: entries con <3 accesos YA no se cargan activamente hoy, democión es transparente |
| Rotation algorithm poorly calibrated | Media | Medio | Umbral configurable, start 3/30d, medir 1 mes antes de ajustar |
| Manual edits a MEMORY.md bypass rotation | Alta | Bajo | Hook detecta desync y rotate al siguiente run |

## Referencias

- GenericAgent `memory/L0_MetaRules.md` — cap + tier pattern
- `docs/memory-system.md` — Savia memory docs actuales
- `docs/rules/domain/context-placement-confirmation.md` — N1-N4b levels
- SE-072 Verified Memory axiom (complementario)
