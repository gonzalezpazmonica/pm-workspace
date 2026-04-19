---
version_bump: minor
section: multiple
---

SE-040 agent degradation canary spec — research Anthropic issue #42796. Era 234.

### Added
- **`docs/propuestas/SE-040-agent-degradation-canary.md`**: skill futuro `agent-health-canary` con 5 métricas canarias (Read:Edit ratio, stop hook violations, interrupt rate, edit-without-read count, token efficiency). Analiza ventana 48h vs baseline 7d de `session-actions.jsonl`. Feasibility Probe 1.5h blocking. Slicing 3 slices.

### Changed
- **`docs/propuestas/ROADMAP.md`**: Tier 4.10 añadido (SE-040 degradation canary). Priorizable alto por evitar cascadas silenciosas cuando proveedor degrada modelo.

### Motivacion
Research del issue anthropics/claude-code#42796: degradación documentada Claude Code desde Feb 2026 sin cambios en código del usuario — Read:Edit cayó 6.6→2.0, stop-hook violations 0→173, coste API/día ×57. Con 65 agentes concurrentes, una regresión pequeña del modelo base se amplifica en cascada. Canary adelanta detección a horas vs semanas. PROPOSED — pendiente revisión humana.
