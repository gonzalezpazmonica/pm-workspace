---
version_bump: patch
section: Added
---
- **SE-374 Guardrail Principle Audit** (`scripts/guardrail-audit.sh` + `scripts/guardrail-inventory-parse.py`): pipeline read-only (python3 stdlib, sin deps) que inventaria 663 guardrails (hooks, gates estructurales, agentes, normas, skills), clasifica por capa NORMA/DISPARADOR/ENFORCEMENT y ejecuta los 12 cruces RN-01..RN-12 contra LEC-1..LEC-4. Salida determinista (fingerprint estable, runtime ~1s) en `output/guardrail-audit/` (gitignored, regenerable). Toda remediación queda como propuesta (RN-12, ART-03).
