## SE-096 — Archive 9 orphan rules (2026-06-24)

### Changed
- docs/rules/domain/hook-event-equivalence.md: added `archived: true` frontmatter (SE-096)
- docs/rules/domain/image-relevance-filter.md: added `archived: true` frontmatter (SE-096)
- docs/rules/domain/portfolio-as-graph.en.md: added `archived: true` frontmatter (SE-096)
- docs/rules/domain/receipts-protocol.en.md: added `archived: true` frontmatter (SE-096)
- docs/rules/domain/savia-memory-architecture.md: added `archived: true` frontmatter (SE-096)
- docs/rules/domain/session-state-location.md: added `archived: true` frontmatter (SE-096)
- docs/rules/domain/slm-consolidation-pattern.md: added `archived: true` frontmatter (SE-096)
- docs/rules/domain/slm-training-pipeline.en.md: added `archived: true` frontmatter (SE-096)
- docs/rules/domain/vault-frontmatter.md: added `archived: true` frontmatter (SE-096)
- scripts/rule-orphan-detector.sh: skip rules with `archived: true` in frontmatter

### Added
- docs/archive/rules/20260624-hook-event-equivalence.md
- docs/archive/rules/20260624-image-relevance-filter.md
- docs/archive/rules/20260624-portfolio-as-graph.en.md
- docs/archive/rules/20260624-receipts-protocol.en.md
- docs/archive/rules/20260624-savia-memory-architecture.md
- docs/archive/rules/20260624-session-state-location.md
- docs/archive/rules/20260624-slm-consolidation-pattern.md
- docs/archive/rules/20260624-slm-training-pipeline.en.md
- docs/archive/rules/20260624-vault-frontmatter.md
- tests/bats/test-se-096-orphan-rules-archive.bats: 3 tests (all pass)

### Notes
- rule-orphan-detector.sh now reports 233 active rules (was 242, -9 archived)
- 2 remaining orphans (glm-governance-protocol, spec-resource-uri) are post-spec state
