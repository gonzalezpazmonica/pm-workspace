---
context_tier: L3
token_budget: 900
---

# Risk Tiering — Gradación de riesgo para auto-merge (SE-362)

> Gobernanza ejecutable: qué tipo de cambio puede auto-mergearse y cuál exige
> humano. Complementa (no sustituye) `autonomous-safety.md` y CRIT-001.

## Tiers

| Tier | Tipo | Gobernanza | Ejemplo |
|---|---|---|---|
| **T1** | Reversible mínimo | auto-merge si CI+spec green (delegado) | fix typo docs |
| **T2** | Reversible módulo | auto-merge + 1 review humano | refactor con tests |
| **T3** | Irreversible / datos | review humana + registro | migración, secrets, push |
| **T4** | Crítico | doble humano + approval formal | infra prod, auth, PII |

## Clasificación

`scripts/risk-tier.py --diff "files"` → JSON con tier + rationale + requires_human.

Reglas deterministas:
- **docs-only** → T1 (si todos los archivos son .md/.txt de docs)
- **paths sensibles** (secret, credential, migration, auth, push, merge, deploy) → T3
- **infra/prod/PII** (infra/, workflows, terraform, production, deploy/) → T4
- **código con tests** → T2
- **fail-closed**: path sin categoría clara → T3 (nunca asume bajo riesgo)

## Integración

`push-pr.sh --merge` consulta risk-tier antes de mergear:
- T1/T2 → auto-merge si grant `merge` vigente (SE-343)
- T3/T4 → bloqueado sin review humana explícita, aun con grant

CRIT-001: todo local; la decisión final siempre es de la operadora.

## Referencias

- SE-362: `docs/specs/SE-362-risk-tiering.spec.md`
- `autonomous-safety.md`, `autonomous-safety-merge-grant.md` (SE-343), CRIT-001
