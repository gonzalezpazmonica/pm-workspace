# Batch 13 — Era 182 closure

**Date:** 2026-04-21
**Branch:** `agent/batch13-tier1-remediation-20260421`
**Version bump:** 5.61.0

## Summary

Cierre formal de la Era 182 (post-audit arquitectónico 2026-04-20). Todos los Tier 0-2 ejecutados en batches 5-12. Esta batch añade la última pieza pendiente: excepción legacy-inline para el normalizador de frontmatter, + actualización del ROADMAP marcando la Era como CLOSED.

## Added

- `scripts/specs-frontmatter-normalize.sh` — detección de legacy-inline format:
  - Si un SPEC file tiene `# SPEC-NNN:` en línea 1 y `**Status**:` inline en las primeras 5 líneas, se skip
  - Razón: añadir YAML frontmatter (12+ líneas) empujaría el header SPEC-NNN fuera del check `head -5` de `validate-spec`
- 3 tests en `tests/test-specs-frontmatter-normalize.bats`:
  - `legacy: SPEC file with inline **Status** and header on line 1 is skipped` (drift=0)
  - `legacy: non-legacy SPEC still migrates normally` (drift=1)
  - `legacy: --apply does not write to legacy files` (md5 preserved)

## Changed

- `docs/ROADMAP.md` — Era 182 marcada CLOSED 2026-04-21:
  - ✅ Tier 0: SE-051 done (batch 6). SE-045 diferido (Enterprise-only, #648)
  - ✅ Tier 1: SE-043/044/046/047/048 done (batches 6-7). SE-054 done con 4 excepciones legacy
  - ✅ Tier 2: SE-050 Slice 2 done (batch 9). SE-052/053 done (batches 7-8)
  - Resumen: 75h ejecutadas vs 112h planificadas. Diferencia = SE-045 Enterprise + eficiencia batch

## Legacy exceptions documentadas

4 specs permanecen en formato body-inline:
- `docs/propuestas/SPEC-066-enhanced-local-llm.md`
- `docs/propuestas/SPEC-067-claudemd-diet.md`
- `docs/propuestas/SPEC-068-hook-enhancement.md`
- `docs/propuestas/SPEC-069-coordinator-mode.md`

Motivo: `# SPEC-NNN:` + `**Status**:` inline en las primeras 5 líneas. La migración rompería el validator.

Mitigación: refactor futuro que mueva `**Status**:` después del `## Problem` dejaría espacio para frontmatter.

## Compliance

- Rule #8: Batch es documentation + test-only, sin spec requerida por ser polish de SE-054 ya aprobado
- No zero egress, no credentials, no PII

## Referencias

- Era 182 origen: `output/audit-arquitectura-20260420.md`
- Roadmap reprioritization: `output/audit-roadmap-reprioritization-20260420.md`
- SE-054 original spec: `docs/propuestas/SE-054-se-036-slices-2-3-finish-frontmatter-mig.md`
