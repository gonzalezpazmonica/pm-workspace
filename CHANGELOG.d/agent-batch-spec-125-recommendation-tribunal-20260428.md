---
version_bump: minor
section: Added
---

## [6.20.0] — 2026-04-28

SPEC-125 PROPOSED — Recommendation Tribunal: real-time audit gate para recomendaciones conversacionales accionables. Cierra una gap crítica reportada por la usuaria: las recomendaciones que Savia da durante un turn no tienen gate (Truth Tribunal cubre reports, Code Review Court cubre código, ambos async). Diseña un panel de 4 jueces (memory-conflict, rule-violation, hallucination-fast, expertise-asymmetry) que intercepta drafts pre-output, con verdict PASS/WARN/VETO, banner inline visible, latency p95 <3s, audit trail JSON, y memory feedback loop para calibración sin re-entreno.

### Added

#### Spec

- `docs/propuestas/SPEC-125-recommendation-tribunal-realtime.md` — diseño completo (3 slices, 36h total estimadas, P0 Critical Path):
  - Slice 1 Foundation (12-16h): classifier + 4 jueces + banner + hook PreToolUse + tests BATS estructurales
  - Slice 2 Asymmetric expertise (8-10h): perfil `expertise.md` por usuario + rewrite mode `blind` con explanation/alternatives/verification
  - Slice 3 Memory feedback loop (8-10h): hook post-turn + calibración sin reentreno usando auto-memory existente
  - Veto rules: contradicción con feedback memory + violación de Rule #1/#8/autonomous-safety/radical-honesty
  - Golden set obligatorio: 50 turns reales para validar precision/recall del classifier (≥0.85)
  - Regression tests: 6 patterns reportadas por la usuaria deben cazarse en ≥5/6
  - Cita Constitutional AI (Anthropic), G-Eval Inline (OpenAI Evals 2026), DeepEval streaming (confident-ai 2026) como pattern sources

### Spec ref

SPEC-125 → status PROPOSED. Implementación pospuesta a Era inmediata (P0). Requiere aprobación humana antes de Slice 1 (sin auto-implementación porque es safety-critical y modifica el flow de salida de cada turn). Dependencias: lee `feedback_*` auto-memories como ground truth; no introduce dependencias externas.

### Hard safety boundaries

- Solo PROPOSAL — no implementación.
- No modifica hooks existentes ni agentes existentes.
- Cero red, cero git operations.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-125-...`, sin push automático ni merge.
