---
version_bump: patch
section: Added
spec: SE-350
---

### Added (SE-350 Slice 2 — Coherence Court cableado en flujos)

- **overnight-sprint** (`scripts/overnight-sprint-loop.sh`): cada tarea completada
  se registra automáticamente como premisa de coherencia (`premises add decision`)
  y al cierre del sprint corre un gate determinista (`check`, sin LLM). Nuevas
  funciones `_coherence_register`/`_coherence_gate`, switch `OVERNIGHT_COHERENCE_GATE=off`.
- **tech-research-agent** y **code-improvement-loop** (skills): registro de premisas
  del plan/hallazgos + gate determinista en las transiciones de fase/mejora.
- **Política anti-saturación**: gate determinista SIEMPRE ON (~0 coste, JSONL local);
  auditoría LLM de 4 jueces OPT-IN al final del flujo, nunca por tarea.
- Deuda pagada: `rule-manifest.json` regenerado (SE-057/SE-338) → `rule-manifest-integrity.sh` PASS.
- CRIT-001: todas las premisas en texto plano local (`data/`), cero red.
