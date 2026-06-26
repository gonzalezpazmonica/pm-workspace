---
spec_id: SPEC-181
title: L0-L3 token budgets explicit per tier
status: IMPLEMENTED
tier: 1
priority: P2
effort: 4-6h
era: 199
wave: 2
deps:
  - SPEC-180
unblocks: []
origin: output/research/obsidian-second-brain-mejoras-cupulas-20260601.md
inspiration: obsidian-second-brain `/obsidian-world` L0-L3 progressive loader
---

# SPEC-181 — L0-L3 context budget enforcement

> Estado: PROPOSED · Tier 1 · P2 · Estimación 4-6h · Era 199 · Wave 2 · Dep: SPEC-180

## Resumen

Cuantificar y hacer cumplir un presupuesto de tokens por tier de carga de contexto (L0 siempre eager, L1 eager por sesión, L2 bajo demanda frecuente, L3 bajo demanda explícita). Hoy la `lazy-reference table` en CLAUDE.md es informal — falta budget y tier explícitos. Aporta predictibilidad de coste por sesión.

## Motivación

- pm-workspace tiene 18 instructions eager (post-PR #793 slim a 11) sin presupuesto explícito. Imposible auditar drift.
- SPEC-156 ya añadió `token_budget` frontmatter a 70 agentes — falta extender a docs.
- Sin tier explícito, decisiones de "qué cargar cuándo" son intuitivas, no reproducibles.

## Scope

1. Definir 4 tiers en `docs/rules/domain/context-tier-budgets.md`:
   - L0: ~200 tokens, siempre eager (identidad mínima).
   - L1: ~1-2K, eager por sesión (CLAUDE.md + active-user + caveman-default).
   - L2: ~2-5K, bajo demanda frecuente (reglas críticas, agents-catalog).
   - L3: ~5-20K, bajo demanda explícita (guías largas, decisiones históricas).
2. Añadir frontmatter `context_tier: L0|L1|L2|L3` y `token_budget: N` a todos los `docs/rules/domain/*.md`.
3. Extender tabla lazy-reference en CLAUDE.md con columnas `Tier` y `Budget` (usando sentinels de SPEC-180).
4. Hook PreToolUse `validate-context-budget.sh` que suma budgets de la sesión y warn si excede 1.5x el tier solicitado.
5. BATS test que verifica que todo doc en `docs/rules/domain/` tiene tier+budget.

## Acceptance Criteria

- AC1: 100% de `docs/rules/domain/*.md` tienen `context_tier` y `token_budget` en frontmatter.
- AC2: Tabla lazy-reference de CLAUDE.md regenerable (vía SPEC-180 sentinel) con columnas Tier/Budget.
- AC3: Suma de budgets L0+L1 ≤ 3000 tokens.
- AC4: Hook warn (no bloquea) si contexto cargado supera 1.5x el tier solicitado.
- AC5: Documento `context-tier-budgets.md` define enum L0..L3 con criterio de pertenencia.
- AC6: BATS test cubre: missing tier → fail, invalid tier value → fail, budget no-numeric → fail, todo válido → pass.
- AC7: Script `scripts/audit-context-budget.sh` reporta tokens totales por tier en JSON.

## Slices

1. **Slice 1 (1h)** — Documentar tiers + criterios en `context-tier-budgets.md`.
2. **Slice 2 (2h)** — Añadir frontmatter a `docs/rules/domain/*.md` (~20 ficheros) + BATS.
3. **Slice 3 (1-2h)** — Hook PreToolUse warn-only + script audit + integración con SPEC-180 para regen tabla CLAUDE.md.
4. **Slice 4 (1h)** — Documentar uso en CLAUDE.md.

## Out of scope

- Bloqueo hard si se excede budget (warn-only en v1).
- Aplicar tiers a `.opencode/skills/` (futuro SPEC).
- UI/dashboard de consumo de contexto en tiempo real.
