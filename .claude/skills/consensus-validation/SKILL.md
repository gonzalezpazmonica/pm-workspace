---
name: consensus-validation
description: Orquestación de 3-judge panel (reflection, code-review, business)
maturity: stable
context: fork
agent: consensus-orchestrator
context_cost: medium
---

# Skill: Consensus Validation

> Lanza 3 jueces especializados. Cada uno evalúa independientemente.
> Output: JSON estructurado con verdicts normalizados, score ponderado, dissents.

**Referencia:** @.claude/rules/domain/consensus-protocol.md

---

## 8-Step Protocol

### 1. Validar Input
```
type: spec | pr | decision
ref: file_path or PR_number
```

### 2. Formatear por Juez
- **reflection-validator:** Suposiciones, cadena causal, brechas de lógica
- **code-reviewer:** Código, diff, reglas SOLID, seguridad
- **business-analyst:** Reglas negocio, criterios aceptación, impacto

### 3-5. Invocar 3 Jueces en Paralelo
Timeout: 40s por juez (120s total).

Cada juez devuelve: verdict + reasoning + confidence

### 6. Normalizar Verdicts a 0/0.5/1.0

| Judge | Verdict → Score |
|---|---|
| Reflection | VALIDATED→1.0 / CORRECTED→0.5 / REQUIRES_RETHINKING→0.0 |
| Code-review | APROBADO→1.0 / CAMBIOS_MENORES→0.5 / RECHAZADO→0.0 |
| Business | VÁLIDO→1.0 / INCOMPLETO→0.5 / INVÁLIDO→0.0 |

### 7. Veto Check
```
if (code_verdict == RECHAZADO) AND (security|gdpr|compliance in reasoning):
  final_verdict = REJECTED
  return early
```

### 8. Calcular Score Ponderado
```
score = (reflection × 0.4) + (code × 0.3) + (business × 0.3)

if score >= 0.75: verdict = APPROVED
elif score >= 0.50: verdict = CONDITIONAL
else: verdict = REJECTED
```

### 8.5. Detectar Dissents
```
avg = (reflection + code + business) / 3
for judge in [reflection, code, business]:
  if abs(judge_score - avg) > 0.5:
    dissents.append(judge)
```

If dissents and verdict == APPROVED → downgrade to CONDITIONAL

### 9. Generar Output JSON
```json
{
  "input": {type, ref, timestamp},
  "judges": [
    {name, verdict, score, reasoning, timeout, elapsed_ms}
  ],
  "veto": {triggered, reason},
  "summary": {
    "weighted_score": 0.62,
    "final_verdict": "CONDITIONAL",
    "dissents": ["business-analyst: ..."],
    "recommended_action": "corrections_required"
  }
}
```

Escribir a: `output/consensus/YYYYMMDD-HHmmss-{type}-{ref}.json`

---

## Dissent Rules

**Triggered si:** `abs(judge_score - promedio) > 0.5`

**Efecto:**
- dissents + APPROVED → CONDITIONAL
- dissents + CONDITIONAL → CONDITIONAL
- dissents + REJECTED → REJECTED

**Output:** listar dissents con razonamiento

---

## Error Handling & Timeline

**Errors:**
- Judge timeout: usar respuesta parcial (⚠️)
- 2+ timeouts: CONDITIONAL
- Veto triggered: REJECTED (final)

**SLA:** 120s máximo

---

## Integration

**SDD:** opt-in after spec-writer
**PR:** mandatory if code-reviewer rejects
**ADR:** opt-in for architecture decisions
**Audit:** persisted in `output/consensus/`

---

## Memory & Antipatterns

- Registra: tendencias jueces, dissent correlations
- **NUNCA:** override veto, modificar verdicts post-facto, saltarse jueces
