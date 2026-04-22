---
id: SPEC-067
title: "CLAUDE.md Diet — Per-Turn Token Optimization"
status: IMPLEMENTED
date: 2026-04-01
era: 165
---

# SPEC-067: CLAUDE.md Diet — Per-Turn Token Optimization

> Implementado en Era 165: CLAUDE.md 121→48 líneas (60% token savings, per-turn cost discovery).

---

## Problem

CLAUDE.md is injected into the first user message every turn — it is NOT part of the cached system prompt. At 121 lines (~605 tokens), this costs full tokens on EVERY turn of EVERY session. In a 50-turn session, that is ~30,000 wasted tokens.

This was discovered during the Claude Code architecture review (2026-03-31). The 150-line rule is not just a readability guideline — it is an economic constraint.

## Solution

Reduce CLAUDE.md from 121 lines to ~50 lines by:

1. **Removing the inline Configuracion code block** (14 lines) — pm-config.md already has all values
2. **Condensing Estructura** (16 → 4 lines) — directory tree is reference, not instruction
3. **Moving rules 9-25 to @import** (17 rules → 1 @import line) — keep only rules 1-8 inline
4. **Condensing Savia section** (12 → 4 lines)
5. **Condensing Subagentes section** (8 → 3 lines)
6. **Moving Packs/Infra/Operaciones** (10 → 2 lines) — already has @imports
7. **Condensing Hooks/Memoria** (12 → 4 lines)

## Files

| File | Action |
|------|--------|
| `CLAUDE.md` | Rewrite: 121 → ~50 lines |
| `docs/rules/domain/critical-rules-extended.md` | NEW: rules 9-25 extracted |

## Acceptance Criteria

- CLAUDE.md ≤ 55 lines
- All @import references resolve to existing files
- Rules 1-8 remain inline (most critical safety rules)
- Rules 9-25 accessible via `@docs/rules/domain/critical-rules-extended.md`
- Zero functionality loss — all information still reachable
- CI validation passes

## Token Savings

| Metric | Before | After | Savings |
|--------|--------|-------|---------|
| Lines | 121 | ~50 | 59% |
| Est. tokens/turn | ~605 | ~250 | ~355 tokens/turn |
| 50-turn session | ~30,250 | ~12,500 | ~17,750 tokens |

## Risks

| Risk | Mitigation |
|------|-----------|
| Claude loses awareness of rules 9-25 | @import loads them on demand when relevant files are touched |
| Too aggressive condensing | Keep full rule text in extended file, only condense CLAUDE.md summaries |
