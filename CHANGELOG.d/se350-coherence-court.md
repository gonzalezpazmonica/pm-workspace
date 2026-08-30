---
version_bump: minor
section: Added
spec: SE-350
---

### Added (SE-350 — Coherence Court)

- **Coherence Court**: componente transversal que extrae el patrón "jueces paralelos
  + scoring + gate" de Code Review Court para auditar la **coherencia relativa**
  entre la salida de una etapa y las premisas/decisiones fijadas en etapas anteriores
  del mismo flujo agéntico (sprint nocturno, investigación autónoma, futuros dominios).
- Nuevo `scripts/coherence-court.sh`: CLI con `check` (gate de flujo multi-etapa),
  `premises` (registro JSONL `data/coherence-premises-{flow}.jsonl`), `skeleton`
  (`.coherence.crc`), `score`, `gate` (puerta humana 0/2/1) y `hash`.
- 4 jueces transversales (factual, scope, objectives, premise-drift) + orchestrator
  en `.opencode/agents/coherence-*.md`, formato de salida gemelo de `.review.crc`
  (schema `coherence-crc.schema.json`).
- Config `rules/coherence.rules.yaml`: thresholds globales + override por flujo.
- CRIT-001: premisas en texto plano local (`data/`), cero red a proveedor.
- 39 tests BATS en `tests/test-se-350-coherence-court.bats`.
