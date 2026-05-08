---
id: SE-069
title: SE-069 — context-rot-strategy skill for 1M context sessions
status: IMPLEMENTED
origin: Opus 4.7 migration analysis 2026-04-23
author: Savia
priority: media
effort: M 5h
gap_link: 1M context window amplifies context rot; no explicit session management skill
approved_at: "2026-04-23"
applied_at: "2026-04-23"
batches: [34]
expires: "2026-05-23"
era: 186
---

# SE-069 — context-rot-strategy skill

## Purpose

Opus 4.7 + 1M context window (current default model: `claude-opus-4-7[1m]`) enables sessions long enough that context rot becomes a first-class concern. As context fills, attention spreads across more tokens, and model intelligence degrades well before the hard limit.

Current Savia skills cover context optimization (`context-optimized-dev`, `context-budget`, `context-compress`) but none formalize the 5-option mental model for per-turn session management or the "compact proactively" heuristic.

## Scope

### Slice 1 — New skill `context-rot-strategy` (M, 3h)

`.opencode/skills/context-rot-strategy/SKILL.md`:

**5-option model per turn:**
1. **Continue** — context still relevant, send another message
2. **Rewind** (double-Esc) — jump back to previous message, drop failed attempts
3. **/compact with hint** — lossy but steered summary ("focus on auth refactor, drop test debugging")
4. **/clear** — fresh session, manual note-taking of what matters
5. **Subagent** — delegate work that generates large intermediate output

**Decision tree:**
- Need the tool output again? → keep in context
- Just the conclusion? → subagent
- Multiple failed attempts clogging context? → rewind
- Session long but still focused? → /compact with hint
- Session drifted topics? → /clear + notes

**Proactive compaction heuristics:**
- Token counter > 60% → flag as yellow (consider compact)
- Token counter > 75% → compact proactively (don't wait for auto-compact at context-rot peak)
- Settings: `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75` already in place ✓

### Slice 2 — DOMAIN.md (Clara Philosophy) (S, 1h)

`.opencode/skills/context-rot-strategy/DOMAIN.md`:
- Why context rot matters (attention diffusion)
- When each of the 5 options is correct
- Anti-patterns (waiting for auto-compact, narrating failures instead of rewinding)

### Slice 3 — BATS tests + script helpers (S, 1h)

`scripts/context-rot-advisor.sh`:
- Reads current context usage (via CLAUDE env vars / token counter if available)
- Recommends one of the 5 options based on thresholds
- BATS tests cover threshold boundaries + output format

## Acceptance criteria

- Skill + DOMAIN.md follow existing 85-skill structure (frontmatter, Decision Checklist, Parameters)
- Advisor script produces deterministic output per usage %
- BATS ≥ 15 tests, score ≥ 80
- Skill registered in workspace (counts bump 85 → 86 skills)
- `readiness-check.sh` PASS (includes new skill in counts)

## Risks

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Skill duplicates existing context-* skills | Alta | Bajo | Positioned as META-skill routing to others; doc explicitly calls out relationship |
| Advisor gives wrong advice if env vars not present | Media | Bajo | Graceful fallback to "continue with caution" |
| Prescriptive thresholds too aggressive/lenient | Media | Medio | Expose as settings env vars with documented defaults |

## No hacen

- Does NOT replace `context-optimized-dev`, `context-budget`, or `context-compress`
- Does NOT auto-invoke compact (user decision)
- Does NOT modify auto-compact settings (already at 75% override)

## Referencias

- Opus 4.7 migration guide: "Context rot is real. You have five options at every turn"
- Current `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75` in settings.json
- Existing: `.opencode/skills/context-budget/`, `context-compress/`, `context-optimized-dev/`
- Complementary: SE-066..SE-068
