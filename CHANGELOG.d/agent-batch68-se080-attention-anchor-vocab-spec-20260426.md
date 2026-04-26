## [6.19.0] — 2026-04-26

Batch 68 — SE-080 spec APPROVED — Attention-anchor vocabulary (Genesis B8/B9/A7/A9 patterns).

### Added
- `docs/propuestas/SE-080-attention-anchor-vocabulary.md` — APPROVED, priority media, effort S 2h, Era 189. Slice único: doc canónico `docs/rules/domain/attention-anchor.md` (~80 líneas) con definición de los 4 patrones Genesis (B8 ATTENTION ANCHOR, B9 GOAL STEWARD, A7 ADVERSARIAL REVIEW, A9 SUPERVISED EXECUTION) + 4 cross-references unilíneas a reglas existentes (radical-honesty.md, autonomous-safety.md, code-review-court.md, SE-079). Output del G13 scope-trace de SE-079 emite "B8 attention-anchor present" en lugar de un check anónimo. Sin código ejecutable nuevo — adopción 100% vocabulary.
- ROADMAP entry bajo Era 189.

### Why this matters
pm-workspace ya implementa los 4 primitives (worker spawn re-injection = B8, Rule #24 = B9, Court 5 jueces = A7, autonomous-safety = A9) sin nombrarlos. Cuando integremos con OpenCode (SE-077), Codex u otros frontends que adopten el catálogo Genesis, nuestros primitives quedan "anónimos" y el otro lado no reconoce que ya cumplimos los patrones. Coste de no nombrar = friction de interoperabilidad. Coste de nombrar = ~120 LOC en docs, sub-1h efectivo.

NO hace: portar el resto del catálogo Genesis (R-tier, A1-A6, B1-B7, B10), crear agente "genesis-architect" (duplicaría spec-driven-development), adoptar `apm`/`npx skills add` (incompatible con autonomous-safety).

### Spec ref
SE-080 — APPROVED, sin implementación todavía. Acoplamiento ligero con SE-079 (no bloqueante).
