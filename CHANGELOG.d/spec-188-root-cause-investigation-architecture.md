---
version_bump: minor
section: Added
---

### Added

- **SPEC-188** Root-Cause Investigation Architecture (meta-spec): 5 piezas P1-P5 (Failure Pattern Memory, Causal Confidence Channel, Investigation-First Hook, Responsibility Judge, Shortcut-Tax Telemetry) con 4 sub-specs detalladas y Fase 0 ejecutada.
- **Fase 0 (SPEC-188)** `.claude/rules/domain/feedback/feedback_root_cause_always.md`: feedback canonico que cierra el hallazgo G3 (memory-conflict-judge referenciaba fichero inexistente). Path N1, tracked, source-of-truth. 10 patrones prohibidos + 4 excepciones documentadas.
- **Tests SPEC-188**: `tests/test-spec-188-architecture.bats` (20 tests) cubre frontmatter, piezas, sub-specs referenciadas, hallazgos, fasificado, feature flags, Bridge SE-072, Fase 0 closure, ROADMAP y CHANGELOG presence.

