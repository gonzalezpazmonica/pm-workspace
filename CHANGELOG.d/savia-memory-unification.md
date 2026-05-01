## [6.15.0] — 2026-05-01

Era 64 — Unificación del sistema de memoria canónica de Savia.

### Added
- `scripts/memory-index-rebuild.sh` — regenera el índice `auto/MEMORY.md` desde el JSONL store.
- `docs/rules/domain/savia-memory-architecture.md` — documento de arquitectura unificada de las 4 capas de memoria (L0-L3).
- `_update_memory_index()` en `memory-store.sh` — actualiza el índice canónico en cada `save`.

### Fixed
- `memory-store.sh`: alias `recall` → `search` — el comando documentado en SKILL.md ya funciona.
- `auto/MEMORY.md` ahora se puebla automáticamente con cada `memory-store.sh save`.
- Índice canónico poblado con 6 entradas (antes vacío).

### Changed
- `memory-cache-rebuild.sh`: escanea `.savia-memory/` + legacy `.claude/projects/` (provider-agnostic).
- `memory-stack-load.sh`: `MEMORY_BASE` → `.savia-memory/` con fallback a legacy.
- `stop-memory-extract.sh`: escribe snapshots en `.savia-memory/sessions/YYYY-MM-DD/`.
- `session-end-memory.sh`: escribe `session-hot.md` en `.savia-memory/sessions/YYYY-MM-DD/`.
- `savia-memory-bootstrap.sh`: marker en `.savia/external-memory-target` en vez de symlink `.claude/external-memory`.
- `memory-agent.md`: paths actualizados a estructura canónica `.savia-memory/`.
- `savia-memory SKILL.md`: documentados `search` y `recall` (ambos válidos), añadido `memory-index-rebuild.sh`.
