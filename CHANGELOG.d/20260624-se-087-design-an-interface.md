## SE-087 — Design-an-interface skill (2026-06-24)

### Added
- `.opencode/skills/design-an-interface/SKILL.md` (≤104 LOC, SE-084 compliant): generates 3 parallel interface design alternatives (A: maxima simplicidad, B: maxima flexibilidad, C: pragmatico) via Task tool sub-agents, consolidates in comparative table, recommends one with justification using SE-082 architectural vocabulary (Module/Interface/Seam/Depth/Locality). Clean-room re-implementation of mattpocock/skills/design-an-interface (MIT). Cross-references SE-082 architectural-vocabulary and SE-074 parallel-specs-orchestrator.
- Decision stays with user — skill never auto-merges or auto-implements.

### Tests
- 15 BATS tests in `tests/structure/test-design-an-interface.bats` (all pass). Covers AC-01..AC-06.

### AC drift fixed in this PR
- AC-02: added MIT attribution to Pocock in frontmatter and header
- AC-04: added SE-074 parallel-specs-orchestrator cross-reference in Related section
- description field updated to pass SE-084 `description-missing-use-when` audit (was WARN, now OK)

### Status
- SE-087 APPROVED → IMPLEMENTED
