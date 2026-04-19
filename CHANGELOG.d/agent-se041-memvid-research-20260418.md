---
version_bump: minor
section: multiple
---

SE-041 memvid portable memory format — Feasibility Probe spec. Era 234.

### Added
- **`docs/propuestas/SE-041-memvid-portable-memory-probe.md`**: spec que propone evaluar mediante Feasibility Probe obligatorio el formato `.mv2` de memvid (github.com/memvid/memvid, 15k stars, Apache 2.0, v2.0 de 2026-03) para 3 usos narrow: backup/restore, snapshot audit, travel portability. NO es reemplazo del stack actual (SPEC-027/018/035/123 ya cubren search+graph). Probe 2h blocking; criterios cuantitativos: ingest 100 docs <30s, retrieval p50 <50ms offline, round-trip byte-identical.

### Changed
- **`docs/propuestas/ROADMAP.md`**: Tier 2.5 añadido (SE-041 memvid probe).

### Motivacion
Research del repo memvid. Veredicto radical honesty: NO resuelve problema bloqueante, pero potencialmente aporta mejor formato de backup con WAL embebido + portabilidad single-file. Adopción global sería duplicar capacidades existentes (SPEC-018/027/035/123); adopción narrow (travel/backup) es el único slot con valor marginal positivo claro. Probe decide empíricamente si entra al stack o se descarta. PROPOSED — pendiente revisión humana.
