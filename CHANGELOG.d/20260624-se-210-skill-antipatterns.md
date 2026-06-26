## SE-210 — Explicit anti-patterns in critical skills

Skills updated with new ## Anti-patterns entries:

- tdd-vertical-slices/SKILL.md: added over-mocking, test-after (had horizontal-slicing, slice-demasiado-grueso)
- grill-me/SKILL.md: added praise-sandwich, rubber-stamp (had critica-generica, scope-creep)
- savia-memory/SKILL.md: added bulk-dump, no-recall, stale-reads (had guardar-sin-tipo, guardar-sin-source)
- spec-driven-development/REFERENCE.md: added spec-after, waterfall-spec, orphan-spec (had AC-no-verificable, merge-sin-aprobacion)

New files:
- docs/rules/domain/skill-antipatterns.md: canonical reference with cross-links to all 4 skills, anti-pattern tables, common root pattern analysis

Tests: tests/bats/test-se-210-skill-antipatterns.bats — 21 tests all passing
All skills within 150-line limit (tdd: 143 lines, grill-me: 75 lines)

Spec: docs/propuestas/SE-210-skill-antipatterns.md
