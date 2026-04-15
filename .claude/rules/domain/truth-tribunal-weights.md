# Truth Tribunal — Weights by Report Type (SPEC-106)

Pesos aplicados al score consolidado de los 7 jueces segun `report_type`.
Cada fila suma 1.0. Deteccion automatica del tipo: ver tabla al final.

## Perfiles

### default (sin tipo declarado)

| Dimensión | Peso |
|-----------|------|
| factuality | 0.20 |
| source_traceability | 0.15 |
| hallucination | 0.20 |
| coherence | 0.10 |
| calibration | 0.10 |
| completeness | 0.10 |
| compliance | 0.15 |

### executive (ceo-report, stakeholder-report, report-executive)

| Dimensión | Peso |
|-----------|------|
| completeness | 0.25 |
| factuality | 0.25 |
| calibration | 0.15 |
| hallucination | 0.15 |
| coherence | 0.10 |
| compliance | 0.05 |
| source_traceability | 0.05 |

Razon: decisiones ejecutivas necesitan datos correctos y cubrir el alcance
completo prometido. Traceability baja porque el CEO no sigue links.

### compliance (compliance-report, governance-report, aepd-compliance)

| Dimensión | Peso |
|-----------|------|
| compliance | 0.30 |
| factuality | 0.25 |
| hallucination | 0.15 |
| source_traceability | 0.15 |
| coherence | 0.05 |
| completeness | 0.05 |
| calibration | 0.05 |

Razon: un informe de compliance que leak PII es peor que uno incompleto.
compliance-judge ademas tiene GATE independiente (score ≥95 required).

### audit (project-audit, security-review, drift-check, governance-audit)

| Dimensión | Peso |
|-----------|------|
| factuality | 0.30 |
| source_traceability | 0.25 |
| completeness | 0.15 |
| hallucination | 0.10 |
| coherence | 0.10 |
| calibration | 0.05 |
| compliance | 0.05 |

Razon: auditorias requieren evidencia trazable para cada hallazgo.

### digest (meeting-digest, pdf-digest, word-digest, excel-digest, pptx-digest)

| Dimensión | Peso |
|-----------|------|
| factuality | 0.25 |
| hallucination | 0.25 |
| source_traceability | 0.20 |
| completeness | 0.15 |
| compliance | 0.10 |
| coherence | 0.03 |
| calibration | 0.02 |

Razon: digests extraen de fuente — alucinacion y factualidad son los
riesgos principales. Coherence/calibration bajas porque el digest
reproduce, no razona.

### subjective (sprint-retro, team-sentiment, burnout-radar)

| Dimensión | Peso |
|-----------|------|
| calibration | 0.30 |
| coherence | 0.20 |
| completeness | 0.15 |
| compliance | 0.15 |
| hallucination | 0.10 |
| source_traceability | 0.05 |
| factuality | 0.05 |

Razon: informes inherentemente subjetivos. Lo clave es que no
sobreafirmen y mantengan consistencia. Factualidad baja pero no cero
(datos objetivos si deben ser correctos).

## Deteccion automatica por comando

| Comando (o prefijo) | report_type |
|---------------------|-------------|
| ceo-report, stakeholder-report, report-executive | executive |
| compliance-*, governance-*, aepd-*, legal-audit | compliance |
| project-audit, security-review, drift-check, arch-health | audit |
| *-digest | digest |
| sprint-retro, team-sentiment, burnout-radar, wellbeing-* | subjective |
| otros | default |

## Override por frontmatter

Un informe puede forzar su tipo:

```yaml
---
report_type: executive
destination_tier: N4
---
```

Si presente, tiene prioridad sobre deteccion heuristica.

## Threshold global

- **PUBLISHABLE**: weighted_score ≥ 90 AND no vetos
- **CONDITIONAL**: 70 ≤ weighted_score < 90 AND no vetos criticos
- **ITERATE**: weighted_score < 70 OR cualquier veto
- **ESCALATE**: tras 3 iteraciones sin alcanzar PUBLISHABLE

## Override compliance absoluto

Para `report_type` ∈ {compliance, audit}: **compliance_judge score ≥ 95**
es gate independiente del consensus. Si compliance <95 → verdict ITERATE
o ESCALATE, sin importar el score ponderado total.
