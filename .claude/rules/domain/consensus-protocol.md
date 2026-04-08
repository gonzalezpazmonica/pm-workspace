---
name: Consensus Protocol — Multi-Judge Validation
description: Orquestación de 3 jueces (reflection, code-review, business) para validar specs y PRs
globs: ["**/*.md", "**/*.cs", "**/*.ts"]
context_cost: medium
---

# Consensus Protocol — Multi-Judge Validation

> Era 25 — Quality Validation Framework. 3 jueces especializados validan specs, PRs y decisiones.

---

## Cuándo Invocar

**Automático:**
- Spec marcada como `ambiguous: true`
- PR rechazada por code-reviewer

**Manual:** `/validate-consensus spec|pr|decision {ref} [--consensus]`

---

## Los 3 Jueces

| Juez | Modelo | Verdicts |
|---|---|---|
| **reflection-validator** | Opus 4.6 | VALIDATED / CORRECTED / REQUIRES_RETHINKING |
| **code-reviewer** | Opus 4.6 | APROBADO / APROBADO_CON_CAMBIOS_MENORES / RECHAZADO |
| **business-analyst** | Opus 4.6 | VÁLIDO / INCOMPLETO / INVÁLIDO |

---

## Scoring (0-1.0 por Juez)

Normalización uniforme:

| Verdict | Score |
|---|---|
| VALIDATED / APROBADO / VÁLIDO | 1.0 |
| CORRECTED / CAMBIOS_MENORES / INCOMPLETO | 0.5 |
| REQUIRES_RETHINKING / RECHAZADO / INVÁLIDO | 0.0 |

**Ponderado por perfil de tarea** (SPEC-092, inspirado en llmfit):

| Perfil | reflection | code | business | Cuándo |
|---|---|---|---|---|
| `default` | 0.40 | 0.30 | 0.30 | Specs genéricas, CRUD, UI |
| `security` | 0.30 | 0.50 | 0.20 | auth, pagos, PII, APIs públicas, encrypt |
| `business` | 0.25 | 0.25 | 0.50 | Reglas de negocio, cálculos, precios, impuestos |
| `architecture` | 0.50 | 0.30 | 0.20 | Infraestructura, migraciones, patrones |

Detección automática por keywords en la spec:
- `auth|security|token|encrypt|PII|password` → `security`
- `rule|calculation|price|discount|tax|billing` → `business`
- `migration|infrastructure|deploy|scale|database` → `architecture`
- Sin match → `default`

Fórmula: `score = (reflection × W_r) + (code × W_c) + (business × W_b)`

---

## Verdicts Finales

| Score | Verdict | Acción |
|---|---|---|
| ≥ 0.75 | APPROVED ✅ | Proceder |
| 0.50-0.74 | CONDITIONAL ⚠️ | Correcciones, re-validar |
| < 0.50 | REJECTED ❌ | Reworking |

---

## Veto Rule

**Rechaza automáticamente (IGNORED score):**
- Security finding en code-reviewer
- GDPR/privacy violation
- Compliance blocker

Un veto anula el score. No hay negociación.

---

## Dissent Handling

Si un juez difiere > 0.5 del promedio:
- Marcar como dissent en output
- Incrementar severidad: CONDITIONAL (en lugar de APPROVED)
- Incluir razonamiento del disidente

---

## Timeout

- **Total para 3 jueces:** 120 segundos máximo
- Por juez: 40 segundos
- Si timeout: usar respuesta parcial (marcar ⚠️)
- Si > 2 jueces timeout: CONDITIONAL (insuficiencia de datos)

---

## Output JSON

Escrito a: `output/consensus/YYYYMMDD-HHmmss-{type}-{ref}.json`

Contiene: input, judges array, veto status, summary (score, verdict, dissents, action)

---

## Integración

| Flujo | Punto de entrada |
|---|---|
| SDD | Opt-in: spec-writer → [--consensus] → implementación |
| PR Review | Mandatory si code-reviewer rechaza → consenso → merge |
| Architecture | Opt-in: ADR propuesta → [--consensus] → decision-log |

---

## Antipatterns (NUNCA)

- ❌ Saltarse jueces por timeout
- ❌ Override de veto por scoring
- ❌ Usar consensus selectivamente
- ❌ Ignorar dissents en CONDITIONAL
- ❌ Auto-approve si falta juez

---

## Ver También

- `consensus-validation/SKILL.md` — Orquestación técnica
- `validate-consensus.md` — Comando usuario
