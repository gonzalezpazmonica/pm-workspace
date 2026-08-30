---
name: Coherence Court
description: Audit consistency of a stage output against premises fixed in earlier stages of the same flow (SE-350)
tier: core
---

# /coherence-court — Transversal Consistency Audit

Runs the Coherence Court on a stage output against the premises registered for
the flow. 4 transversal judges (factual, scope, objectives, premise-drift) review
in parallel, producing a `.coherence.crc` verdict with a 0-100 score and a human
gate when the score falls under threshold.

## Usage

```
/coherence-court --flow <flow> --stage-output <file>
/coherence-court --flow <flow> --stage-output <file> --register-only   # solo registrar premisas
```

## Flow

1. **Gate**: `bash scripts/coherence-court.sh check --flow F --stage-output FILE` —
   FAIL if flow has no premises (single-stage flow, nothing to compare).
2. **Premises**: ensure prior-stage premises are registered:
   `bash scripts/coherence-court.sh premises F add <kind> <content>` (kind:
   fact|constraint|objective|decision).
3. **Skeleton**: `bash scripts/coherence-court.sh skeleton F FILE` → `.coherence.crc`.
4. **Judges**: launch 4 subagents in parallel via `coherence-court-orchestrator`:
   - `coherence-factual-judge`: fact contradictions with prior stages
   - `coherence-scope-judge`: scope/constraint violations
   - `coherence-objectives-judge`: declared-objective contradictions
   - `coherence-premise-drift-judge`: silent premise drift
5. **Consolidate**: score = 100 - (C×25 + H×10 + M×3 + L×1). Write `.coherence.crc`.
6. **Gate**: `bash scripts/coherence-court.sh gate <score>` → PASS/CONDITIONAL/FAIL.
7. **Report**: discrepancies summary to the user.

## Verdicts

| Score | Verdict | Next step |
|-------|---------|-----------|
| 90-100 | pass | Continuar flujo, revisión humana ligera |
| 70-89 | conditional | Revisar discrepancias antes de continuar |
| < 70 | fail | **Puerta humana**: NO continuar el flujo — humano decide |

## Principles

- "Se delega la ejecución, nunca el criterio" — Coherence Court señala, no corrige.
- "Humano decide" — gate obligatorio cuando el score cae bajo umbral.
- CRIT-001 — premisas en texto plano local (`data/`), sin salir de la máquina.
