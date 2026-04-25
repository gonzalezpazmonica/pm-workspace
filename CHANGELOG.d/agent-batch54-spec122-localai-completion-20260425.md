## [6.5.0] — 2026-04-25

Batch 54 — SPEC-122 LocalAI emergency-mode hardening **IMPLEMENTED** (4 ACs faltantes completados).

### Added
- `.claude/hooks/emergency-mode-readiness.sh` — SessionStart async hook (AC-03). Ejecuta `localai-readiness-check.sh` solo si `EMERGENCY_MODE_ENABLED=true`. Surface FAIL/WARN a stderr para visibilidad usuario, log append-only a `output/emergency-mode/readiness.jsonl`. Timeout 10s en script invocation, nunca bloquea SessionStart.
- `tests/test-emergency-mode-readiness.bats` — 30 tests certified (score 94). Cubre verdict states (READY/WARN/FAIL/SKIP/TIMEOUT/UNKNOWN), feature-flag silencio, mock script via `$CLAUDE_PROJECT_DIR`, append accumulation, edge cases.

### Changed
- `.claude/settings.json` — registra `emergency-mode-readiness.sh` en SessionStart con timeout 12s y statusMessage descriptivo.
- `docs/rules/domain/autonomous-safety.md` — sección "Emergency-mode (LocalAI fallback) — SPEC-122" añadida (AC-05). Prohibiciones explícitas: NUNCA bypass AUTONOMOUS_REVIEWER, ramas agent/*, PR Draft en emergency-mode. Emergency-mode cambia SOLO el endpoint de inferencia.
- `docs/propuestas/SPEC-122-localai-emergency-hardening.md` — status PROPOSED → IMPLEMENTED. Resolution section con 7/7 ACs cumplidos.

### Context
SPEC-122 ACs 01/02/04 ya implementados desde batches previos (script `localai-readiness-check.sh`, SKILL.md sección LocalAI, `emergency-mode-protocol.md` doc). Este PR completó los 4 AC faltantes: hook (AC-03), autonomous-safety nota (AC-05), tests (AC-06), CHANGELOG (AC-07).

Hook coverage: 58/58 → 59/59 (100% mantenido — nuevo hook tested desde el primer commit).

Diseño fail-safe: hook silent-skip cuando flag off (zero cost por defecto), nunca bloquea SessionStart, surface verdicts críticos al usuario sin imponer acción.

Version bump 6.4.0 → 6.5.0.
