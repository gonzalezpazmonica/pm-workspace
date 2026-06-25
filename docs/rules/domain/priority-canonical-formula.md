---
context_tier: L2
token_budget: 1400
resource: internal://docs/rules/domain/priority-canonical-formula.md
spec: SPEC-154
---

# Regla: Fórmula Canónica de Priorización V×U/E

> Fuente de verdad para toda decisión de priorización en Savia.
> Implementada en `scripts/priority/score.py`. Schema: `docs/schemas/priority-v1.json`.

## La fórmula

```
priority_score = (value × urgency) / effort_normalized
```

Mismo input → mismo output (función pura, AC-01). Auditabilidad total (Rule #24).

---

## Escala VALUE (1-100): impacto absoluto

| Puntuación | Significado | Ejemplo concreto |
|---|---|---|
| 1-20 | Cosméticos / nice-to-have | Cambiar color de un botón interno |
| 21-40 | Mejora visible, sin bloquear | Mejorar mensaje de error en log |
| 41-60 | Mejora observable, uso frecuente | Acelerar 30% una pantalla de consulta |
| 61-80 | Desbloquea otros items o equipos | API que 3 features downstream esperan |
| 81-90 | Multiplica capacidad del sistema | Motor de priorización unificado (esta spec) |
| 91-100 | Seguridad/compliance/fundacional | Zero-leak PII, autenticación, fundación arquitectónica |

**Anti-pattern**: inflar value para subir en el ranking. El decision_trail hace visible la inflación — cualquier auditor puede preguntar "¿por qué 90 y no 70?" y exigir evidencia.

---

## Árbol de decisión URGENCY (1-100)

**Urgency = pendiente de degradación temporal del value. NO es ansiedad ni presión social.**

```
¿Hay deadline externo fijo (regulatorio, contrato, release date)?
  YES → 85-100
  NO → ¿El coste de no hacerlo ahora crece cada semana (deuda, bloqueados)?
    YES → ¿Crece rápido (>1 equipo bloqueado, degradación de datos)?
      YES → 70-85
      NO → 50-70
    NO → ¿Puede esperar 1-2 sprints sin coste real?
      YES → 20-50
      NO → 1-20 (prácticamente sin urgencia temporal)
```

**Qué NO es urgency:**
- "El equipo quiere hacerlo" → value, no urgency
- "El PM dice que es urgente" → verificar si hay deadline real o ansiedad
- "Lleva mucho tiempo en el backlog" → relevante solo si hay deuda acumulativa

---

## Componentes EFFORT (4 sub-factores, pesos)

`effort_normalized = 0.4×hrs + 0.3×risk + 0.2×cog + 0.1×tokens`

| Sub-factor | Peso | Escala | Qué mide |
|---|---|---|---|
| `human_review_hours` | 40% | 0h=1 → 8h+=100 | Revisión humana: code review, testing manual, sign-off, aprobación |
| `regression_risk` | 30% | 1-5 → ×20 | 1=aislado, 3=módulo compartido, 5=cross-cutting crítico |
| `cognitive_complexity` | 20% | 1-5 → ×20 | 1=trivial, 3=requiere contexto del dominio, 5=experto necesario |
| `tokens` | 10% | 0-50k → 1-100 | Tokens LLM estimados (proxy de complejidad técnica) |

**Por qué human_review_hours tiene el peso mayor (40%)**: subestimar el coste humano es el sesgo más común. Una tarea de 2h de código puede requerir 8h de revisión, QA, demo y aprobación.

---

## Cuándo NO usar esta fórmula

1. **Items sin V/U/E declarados**: emitir `BLOCKED: missing {field}` y excluir del ranking (AC-07). Nunca inventar.
2. **Decisiones de arquitectura con incertidumbre extrema**: usar `confidence: baja` y marcarlo explícitamente. El score es orientativo, no prescriptivo.
3. **Comparaciones cross-dominio sin calibración**: no comparar score de un spike técnico (value=20) con un blocker de compliance (value=95) sin contextualizar.
4. **Sprints ya en ejecución**: la re-priorización mid-sprint requiere cambio de scope explícito, no solo recalcular scores.

---

## Anti-patterns

| Anti-pattern | Señal | Corrección |
|---|---|---|
| **Gaming de value** | value=95 para tarea cosmética | Decision trail exige justificación. Auditor compara con escala. |
| **Urgency == ansiedad** | urgency=90 porque "el PM quiere esto" | Verificar: ¿hay deadline externo? ¿qué pasa si espera 1 sprint? |
| **Alucinación de escala** | Agente inventa value=50 para item sin metadata | AC-07: BLOCKED hasta que humano declara V/U/E |
| **Ignorar human_review** | effort_score=5 para tarea con 16h de revisión | human_review_hours es campo requerido — imposible ignorar |
| **Priority_score manual** | Humano escribe priority_score directamente | priority_score es calculado, no manual. Solo score.py lo escribe. |

---

## Adapters disponibles

| Origen | Adapter | Nota |
|---|---|---|
| RICE | `scripts/priority/adapters/rice_to_vue.py` | Spearman > 0.8 target (AC-04) |
| WSJF | `scripts/priority/adapters/wsjf_to_vue.py` | CoD mapeado a value+urgency |
| Ad-hoc (text) | `scripts/priority/adapters/adhoc_to_vue.py` | confidence=0.65, warning emitido |

Los adapters son puentes, no sustitutos. El input directo V/U/E siempre es preferible.
