---
id: LP-20260823-meta-pruebas
type: learning_proposal
provenance: INFERRED
lifecycle: proposed
origin: L13 F3 pruebas M1-M4 2026-08-23: el harness determinista sobre la capa metacognitiva confirma el mecanismo (CONFIRMA 4/4) sin LLM
trigger: recurrence
target: skill
criterion_id: 
evidence_hash: 24163ea0e0729015
created_utc: 2026-08-23T02:45:00Z
expected_p_consistent: 
---

# Learning Proposal LP-20260823-meta-pruebas

## Origen

L13 F3 pruebas M1-M4 2026-08-23: el harness determinista sobre la capa
metacognitiva confirma el mecanismo (CONFIRMA 4/4) sin LLM

## Evidencia

scripts/meta-monitor.sh:scripts/meta-control.sh:scripts/meta-recalibrate.sh:scripts/l13-meta-pruebas.sh

## Diagnóstico

El harness run-1 (sin LLM, CRIT-001) valida las 4 pruebas preregistradas M1-M4
de la capa metacognitiva sobre SAGI: (1) calibración — el ajuste reduce el gap
de confianza (baseline 15 → 13.5); (2) divergencia-modula — confidence_adjusted
decrece monotónicamente con divergence (4/4 transiciones); (3) autorregulación —
meta-control POSTPONE evita emitir una propuesta que el baseline emitiría;
(4) recalibración — el gap decrece entre bloques (60.4 → 28.4) al nutrir la
curva. El mecanismo funciona determinista; falta la señal real (F4).

## Cambio propuesto

Seguir L13 F4: conectar el resultado real (auditor, feedback humano, ledger
SE-255) a la curva de calibración y re-ejecutar el harness con señal real. La
capa propone, nunca auto-activa (CRIT-031).

## Destino

skill

## Métrica esperada

sin baseline declarado