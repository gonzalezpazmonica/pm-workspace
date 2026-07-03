---
spec_id: SE-237
title: "Patrón Coarse-to-Fine en DAG Scheduling"
status: IMPLEMENTED
created: 2026-06-28
resolved_at: "2026-07-02"
implementation_pr: "#889"
author: savia
context_tier: L2
token_budget: 560
inspired_by: "Proto (Arc Institute, 2026) — multi-stage pipeline: rejection sampling barato → MCMC costoso"
---

# SE-237: Patrón Coarse-to-Fine en DAG Scheduling

## Motivación

Proto usa un pipeline multi-stage donde:

- **Stage 1**: Rejection Sampling barato (5000 muestras, constraints simples, < 1s por muestra) filtra el espacio de búsqueda
- **Stage 2**: MCMC con AlphaFold (costoso, > 60s por evaluación) solo se ejecuta sobre los mejores candidatos del Stage 1

Los constraints caros se relegan al stage final. El resultado: el 95% de candidatos se eliminan con < 1% del coste total.

En Savia el pipeline SDD ya tiene esta estructura de forma implícita, pero:
1. No está documentado como patrón explícito
2. Algunos pipelines invocan `court-orchestrator` (EXPENSIVE) antes de `test-runner` (CHEAP)
3. No hay un validador que detecte estas inversiones de coste

## Definición del Patrón

### Tipos de Gate

| Tipo | Coste | Criterio | Ejemplos en Savia |
|------|-------|----------|-------------------|
| CHEAP | < 5s, sin LLM | Validación sintáctica, checks de estructura | `dag-typing-validate`, `spec-validator`, `bash -n syntax check` |
| MEDIUM | 5-60s, LLM ligero | Análisis semántico, inferencia rápida | `feasibility-probe`, `test-runner`, `lint checks` |
| EXPENSIVE | > 60s, LLM pesado | Review completo, multi-agente | `court-orchestrator`, `truth-tribunal`, `security-attacker` |

### Clasificación de agentes Savia

**CHEAP (< 5s, sin LLM)**:
- `dag-typing-validate.sh` — validación estructural de DAGs
- `spec-validator.sh` — validación de frontmatter
- `hashline-guard.sh` — integridad de hashes
- `validate-bash-global.sh` — syntax checks bash
- `block-force-push` (plugin) — regla determinística

**MEDIUM (5-60s, LLM ligero)**:
- `feasibility-probe` — viabilidad rápida de spec
- `test-runner` — suite de tests unitarios
- `dev-orchestrator` — planificación de slices
- `coherence-validator` — validación semántica

**EXPENSIVE (> 60s, LLM pesado)**:
- `court-orchestrator` — review completo 5 jueces
- `truth-tribunal-orchestrator` — 7 jueces de veracidad
- `security-attacker` + `security-defender` — pipeline adversarial
- `{lang}-developer` — implementación completa

### Pipeline SDD Recomendado (Coarse-to-Fine)

```
Stage 1 (CHEAP):
  spec-validator → dag-typing-validate → hashline-guard

Stage 2 (MEDIUM):
  feasibility-probe → dev-orchestrator → test-runner

Stage 3 (EXPENSIVE):
  {lang}-developer → court-orchestrator
```

Cada stage actúa como filtro. Si Stage 1 falla, no se ejecuta Stage 2. Coste total esperado: Stage 1 descarta ~40% de specs malformadas antes de gastar en LLMs.

### Anti-patrón

```
# INCORRECTO — court-orchestrator antes de test-runner
court-orchestrator → test-runner → feasibility-probe

# CORRECTO
feasibility-probe → test-runner → court-orchestrator
```

### Cuándo saltarse el orden

Está permitido invocar un gate EXPENSIVE antes de tiempo si:

1. El operador declara explícitamente `--skip-coarse-to-fine` con justificación
2. Es una revisión de emergencia (`--emergency-review`)
3. El pipeline tiene solo 1 stage (no hay ordenación que violar)

## Validador

`scripts/dag-gate-cost-checker.sh` verifica que en un DAG definido en YAML/JSON, los gates CHEAP aparecen antes que MEDIUM y EXPENSIVE.

## Tests

Ver `tests/test-se237-coarse-to-fine.bats` — 10 tests.

## Criterio de éxito

- `docs/rules/domain/coarse-to-fine-gates.md` existe con clasificación de los 3 tipos
- `dag-gate-cost-checker.sh` detecta inversiones de orden y devuelve exit 1 con descripción
- Un DAG correcto (cheap→medium→expensive) pasa con exit 0
- Los 10 tests BATS pasan en verde
