# SE-376 — Structural Quality Debt Burn-down

**Estado:** PROPOSED (pendiente de aprobación humana — Fase E, audit GPT-5.6 2026-09-05)
**Prioridad:** P0 · **Developer Type:** agent-team · **Context Risk:** medium
**Origen:** auditoría externa §7 (STILL_RECOMMENDED con baseline corregido)

## 1. Motivación

Los ratchets impiden empeorar pero no obligan a reducir deuda (F3). Cifras del auditor NO reproducen y se corrigen:

| Métrica audit | Real medida 2026-09-05 | Fuente |
|---|---|---|
| "27 agentes sobredimensionados" | **0** (ningún agente >150 líneas) | `validate-ci-local.sh:29-30` sobre `.opencode/agents` |
| "155 skill-quality-violations" | **132 skills no calibradas** (2 Calibrated / 124 Incomplete / 8 Stub / 0 Deprecated) | `scripts/skill-maturity-audit.sh` (SE-167), `output/skill-maturity-kanban-20260905.md` |

## 2. Alcance

Programa de burn-down sobre la deuda REAL medida por los gates existentes (SE-167 kanban, size gates, ci-reliability), no sobre cifras del audit.

### Debt budget (formato)

```yaml
skill_maturity:
  current: 132        # Incomplete+Stub
  target_wave_1: 90
  target_wave_2: 40
  final: 0            # o excepciones aprobadas explícitamente
agent_size:
  current: 0
  final: 0
```

### Clasificación de cada violación

`DELETE | MERGE | SPLIT | REFACTOR | FALSE_POSITIVE | LEGITIMATE_EXCEPTION`

## 3. Reglas

- Nunca subir baseline. Nunca relajar threshold sin spec explícita.
- Nunca añadir excepción solo para silenciar el auditor.
- Toda excepción registra: razón, owner, fecha, re-evaluation date.
- Antes de SPLIT, comprobar MERGE/DELETE. Antes de ampliar una skill, comprobar overlap (SE-270).
- Arreglar una capability NO debe significar hacerla más grande.

## 4. Criterios de aceptación

- Inventario completo con clasificación por skill.
- Cada wave reduce el baseline del budget (verificable en CI).
- Cero regresiones en evals de comportamiento (paired-delta).
- Objetivo final: 0 o excepciones aprobadas por la operadora.

## 5. OpenCode Implementation Plan

PENDING-APPROVAL — al aprobar, completar según `docs/rules/domain/spec-opencode-implementation-plan.md`.

## Referencias

- Auditoría externa §7 · SE-167 · SE-270 · SE-046 `baseline-tighten.sh` · SPEC-109
