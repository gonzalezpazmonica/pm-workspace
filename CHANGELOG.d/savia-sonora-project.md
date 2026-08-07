---
version_bump: minor
section: Added
---

### Added

- Proyecto unificado **savia-sonora** (`projects/savia-sonora/`): la interfaz hablada de Savia (voz y oido). Consolidacion Fase 0 (identidad) + Fase 1 (reubicacion) completadas:
  - `git mv` del nucleo: `projects/savia-transcriptor` → `projects/savia-sonora/app` (app completa: src-pyloid, React, installers Win/Linux/macOS, CI).
  - Spec SE-310 → `projects/savia-sonora/specs/`; SE-308 queda en `app/specs/`.
  - Referencias de path actualizadas (specs, README, RESUME, ROADMAP, skill transcriptor-digest → Savia Sonora).
  - Motor TTS (Kokoro) se mantiene en `scripts/` como capa compartida del workspace, owned por Savia Sonora (moverlo romperia la API TTS SE-075 y 15+ referencias). Entry point cross-platform = `savia-kokoro.py` (Python); wrappers bash = conveniencia POSIX.
- Cross-platform (Linux/Windows/macOS): app Python/Pyloid; runtime `~/.savia/transcriptor/` mantenido (compatibilidad de datos).
- Roadmap Era 202 y SKILLS.md actualizados.
