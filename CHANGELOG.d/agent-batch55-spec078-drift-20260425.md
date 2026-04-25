## [6.6.0] — 2026-04-25

Batch 55 — SPEC-078 dual-estimation status drift correction (PROPOSED → IMPLEMENTED).

### Changed
- `docs/propuestas/SPEC-078-dual-estimation-agent-human.md` — status PROPOSED → IMPLEMENTED. Resolution section con verificación de los 4 deliverables Fase 1 MVP: `dual-estimate.sh` (engine CLI), `test-dual-estimate.bats` (score 82), `dual-estimation-gate.sh` (PostToolUse warning hook), `docs/politica-estimacion.md` (política dual). 5/5 AC Fase 1 cumplidos. Fases 2-4 (auto-estim, tracking, capacity dual) quedan como evolución gradual, no bloquean IMPLEMENTED status.

### Context
Tercer drift fix de la sesión (post SPEC-055, SPEC-121, SPEC-122). Implementación inicial fue Era 179 (auditoría correctiva 2026-04-04) pero status nunca se flippó. Verificación deep: engine CLI funcional, hook activo en standard tier, política documentada con regla de oro y matriz decisión.

PROPOSED priority alta restantes tras este batch: 1 (SPEC-124 pr-agent wrapper, ~50% implementado, 5 ACs reales pendientes — no es drift, es trabajo real).

Version bump 6.5.0 → 6.6.0.
