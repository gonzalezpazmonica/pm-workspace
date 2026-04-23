# Batch 34 — SE-069 context-rot-strategy skill

**Date:** 2026-04-23
**Version:** 5.79.0 (batch combinado 31-35)

## Summary

Opus 4.7 trae 1M context window como default (Savia ya corre `claude-opus-4-7[1m]`). Pero ventana grande != atencion escalable — context rot es real y la degradacion de calidad empieza mucho antes del limite fisico. Ninguna skill formalizaba el 5-option mental model ni los umbrales proactive-compact.

## Cambios

### A. Nueva skill `context-rot-strategy`
`.claude/skills/context-rot-strategy/SKILL.md` + `DOMAIN.md`.

**5 opciones per turn**:
1. Continue (default, < 60% usage)
2. Rewind (double-Esc, drop failed attempts)
3. /compact con hint (lossy dirigido)
4. /clear (fresh + session-journal.md)
5. Subagent (delegar output grande)

**Umbrales**:
- 0-60% Verde (continue libre)
- 60-75% Amarillo (planifica corte)
- 75-90% Rojo (compact PROACTIVO antes de auto-compact)
- 90%+ Critico (/clear + notas)

Settings actual `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75` ya esta alineado con el umbral rojo.

### B. DOMAIN.md (Clara Philosophy)
Cubre: por-que-importa (attention diffusion), por-que-ahora (Era 186 Opus 4.7 + 1M), que-evita (auto-compact tardio, sesiones zombies), evidencia real (8h sesion rinde como 2h fresh sin cortes), relacion con otras skills context-*.

## Validacion

- `scripts/opus47-compliance-check.sh --context-rot-skill`: PASS
- SKILL.md + DOMAIN.md presentes
- CLAUDE.md bump 85 → 86 skills
