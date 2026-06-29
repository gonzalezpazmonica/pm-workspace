---
context_tier: L2
token_budget: 400
spec_ref: SE-237
---

# Coarse-to-Fine Stage Gating — DAG Scheduling (SE-237)

> Patrón inspirado en Proto (Arc Institute, 2026): multi-stage pipeline donde constraints
> baratos filtran antes de que los costosos evalúen. Reduce el coste total eliminando
> candidatos malos con < 1% del presupuesto total.

## Tipos de Gate

| Tipo | Coste | Criterio | Orden |
|------|-------|----------|-------|
| CHEAP | < 5s, sin LLM | Validación sintáctica, checks de estructura | 1 (primero) |
| MEDIUM | 5-60s, LLM ligero | Análisis semántico, inferencia rápida | 2 (segundo) |
| EXPENSIVE | > 60s, LLM pesado | Review completo, multi-agente | 3 (último) |

## Clasificación de agentes Savia

### CHEAP (< 5s, sin LLM)

- `dag-typing-validate.sh` — validación estructural de DAGs
- `spec-validator.sh` — validación de frontmatter y estructura
- `hashline-guard.sh` — integridad de hashes de ficheros
- `validate-bash-global.sh` — syntax check de scripts bash
- `block-force-push` (plugin) — regla determinística sin inferencia
- `spec-id-duplicates-check.sh` — duplicados de spec IDs

### MEDIUM (5-60s, LLM ligero)

- `feasibility-probe` — viabilidad rápida de spec (ejemplo de gate CHEAP en proto)
- `test-runner` — suite de tests unitarios
- `dev-orchestrator` — planificación de slices
- `coherence-validator` — validación semántica ligera
- `lint-checks` — análisis estático de código

### EXPENSIVE (> 60s, LLM pesado)

- `court-orchestrator` — review completo 5 jueces (ejemplo de gate EXPENSIVE en proto)
- `truth-tribunal-orchestrator` — 7 jueces de veracidad
- `security-attacker` + `security-defender` — pipeline adversarial completo
- `{lang}-developer` — implementación de feature completa

## Pipeline SDD Recomendado

```
Stage 1 (CHEAP):    spec-validator → dag-typing-validate → hashline-guard
Stage 2 (MEDIUM):   feasibility-probe → dev-orchestrator → test-runner
Stage 3 (EXPENSIVE): {lang}-developer → court-orchestrator
```

Cada stage actúa como filtro. Si Stage 1 falla → no ejecutar Stage 2.

## Anti-patrón

```
# INCORRECTO — court-orchestrator antes de test-runner
court-orchestrator → test-runner → feasibility-probe

# CORRECTO
feasibility-probe → test-runner → court-orchestrator
```

## Cuándo saltarse el orden

Permitido solo si:
1. El operador declara explícitamente `--skip-coarse-to-fine` con justificación
2. Es una revisión de emergencia (`--emergency-review`)
3. El pipeline tiene solo 1 stage (no hay ordenación que violar)

## Validador

`scripts/dag-gate-cost-checker.sh` verifica que en un DAG YAML/JSON, los gates CHEAP
aparecen antes que MEDIUM y EXPENSIVE.

Exit codes: 0=orden correcto, 1=violación detectada.
