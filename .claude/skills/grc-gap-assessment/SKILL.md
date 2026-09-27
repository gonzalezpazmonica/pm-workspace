---
layer: peripheral
layer: peripheral
name: grc-gap-assessment
description: Construye matriz GRC preliminar y acciones trazables. Usar cuando se solicita gap assessment, auditoría interna o resumen ejecutivo.
metadata:
  savia.maturity: incomplete
  savia.category: governance
  savia.context: standalone
  savia.context_cost: low
  savia.priority: high
  savia.tags: grc,gap,reporting
---
# GRC Gap Assessment

## Authoritative Paths

| Para | Lee |
|---|---|
| Contrato y ejemplo | `docs/grc/README.md` |
| Evaluador determinista | `scripts/grc-audit.py` |
| Autoridad y límites | `docs/specs/SE-GRC-001-grc-auditor.spec.md` |

## Flujo

1. Valida alcance, requisitos y aplicabilidad con `grc-framework-router`.
2. Recopila y prueba evidencias con `grc-evidence-analysis`.
3. Ejecuta el evaluador local. Revisa estados, contradicciones y cobertura; no traduzcas ausencia de evidencia a incumplimiento formal.
4. Adjunta a cada hallazgo borrador requisito, control y evidencia adversa. Propón escenario de riesgo y tratamiento, con propietario para revisión.
5. Resume postura, riesgos materiales, decisiones pendientes y límites. Usa recuentos por estado; evita porcentajes sin metodología definida.

## Salidas

Matriz de evaluación preliminar, hallazgos borrador, riesgos propuestos y resumen ejecutivo. Las aprobaciones y cierres quedan fuera de esta skill.
