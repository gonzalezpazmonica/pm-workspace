# Batch 18 — SE-035 Slice 2 mutation-audit skill

**Date:** 2026-04-21
**Branch:** `agent/batch18-se035-mutation-ci-20260421`
**Version bump:** 5.66.0

## Summary

Segundo champion Tier 3 (post-SE-061). El script `scripts/mutation-audit.sh` ya existía desde batch 9. Este slice añade la skill wrapper que permite invocación discoverable y documenta cuándo usar (sprint-end, post-test-generation) vs cuándo no (cada PR, módulos sin tests).

## Added

- `.claude/skills/mutation-audit/SKILL.md` (137 líneas):
  - Invocación con `bash scripts/mutation-audit.sh --target X --tests Y`
  - Output verbose + JSON
  - Mutadores Slice 1: arithmetic-op-swap, comparison-boundary, conditional-negate, return-null
  - Threshold interpretation (≥80% fuerte, 70-79% aceptable, <70% débil)
  - "Cuando NO usar": cada PR, módulos sin tests, lenguajes fuera de Slice 1

- `.claude/skills/mutation-audit/DOMAIN.md`:
  - Problema: cobertura alta ≠ tests efectivos (zombies AI-generated)
  - Métrica: mutation score = matados/totales
  - Integración: sprint-end, test-engineer, overnight-sprint, PR opcional
  - Tradeoffs + roadmap futuro (Slice 2+ mutadores, Slice 3 regeneración, Slice 4 trending)

- `tests/test-mutation-audit-skill.bats` (33 tests certified):
  - Skill existence + size
  - Frontmatter validation (name, description, maturity, category, allowed-tools)
  - Content references (SE-035, mutation-audit.sh, score formula)
  - Negative cases (no target, bad flag, missing tests)
  - Edge cases (empty dir, nonexistent target, zero mutants, >20 boundary)
  - Isolation + coverage

## Changed

- `CLAUDE.md`: skills count 79 → 80 (drift-check compliance)

## Compliance

- Rule #8: Slice 2 sobre SE-035 spec PROPOSED. Wrapper skill + tests — no nuevo código ejecutable
- Zero egress, zero credentials, zero PII
- Research origen: 2026-04-18 (research/javiergomezcorio substack documentado en spec)

## Roadmap Tier 3 status

1. ✅ SE-061 Scrapling (batches 14-17, 4 slices, 103 tests)
2. ✅ SE-035 Mutation testing Slice 2 skill (this batch)
3. ⏳ SE-032 Reranker skill integration (probe ready)
4. ⏳ SE-033 BERTopic skill + corpus (probe ready)
5. ⏳ SE-028 Oumi training pipeline (probe ready)
6. ⏳ SE-041 Memvid backup workflow (probe ready)

## Referencias

- Spec: `docs/propuestas/SE-035-mutation-testing-skill.md`
- Script: `scripts/mutation-audit.sh`
- Roadmap: `docs/ROADMAP.md` §Era 183 Tier 3 Champions
