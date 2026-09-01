# SE-362 — Gradación de riesgo para auto-merge: gobernanza ejecutable por tier

**Status:** APPROVED (2026-08-31, operadora grant merge sesión nocturna)
**Fecha:** 2026-08-31
**Área:** Gobernanza / Autonomous safety
**Fuente de inspiración:** Anthropic AI-Native SDLC Playbook (criterios escritos para auto-merge de bajo riesgo; gobernanza ejecutable) + modelo de riesgo Amplitude
**Criterio humano aplicable:** CRIT-001

---

## Objetivo

Definir una **gradación de riesgo explícita** para los cambios que Savia produce,
que permita clasificar un cambio en un tier y asociar a cada tier un nivel de
gobernanza: desde auto-merge sin humano (bajo riesgo) hasta review humana
obligatoria (alto riesgo). La gradación complementa — no sustituye — el
principio actual "humano decide en toda escritura al vault" (CRIT-001/N3+),
que sigue aplicando a datos confidenciales.

## Contexto

El playbook de Anthropic propone "gobernanza ejecutable": definir explícitamente
qué tipo de cambio es seguro fusionar sin humano, con una gradación de riesgo.
Verificado en Savia: `CRITERIO.md` tiene CRIT-022 (reversibilidad decide la
velocidad) y `autonomous-safety.md` prohíbe merge autónomo en general. El gap:
**no hay gradación escrita** — el modelo actual es binario (todo merge requiere
humano), sin distinguir un cambio de docs de un cambio de infraestructura crítica.
La operadora concedió merges en esta sesión nocturna caso por caso; una gradación
formal haría esa delegación sistemática y auditable.

**Rechazo explícito (CRIT-001):** la gradación es local y la decisión final
siempre la toma la operadora (la IA propone, el humano dispone). El auto-merge
solo aplica a cambios que la operadora ha delegado explícitamente por tier.

## Diseño

### 1. Taxonomía de riesgo (Tiers 1-4)

| Tier | Tipo de cambio | Gobernanza | Ejemplo |
|---|---|---|---|
| **T1 — Reversible mínimo** | docs/typos/chore sin datos | auto-merge si CI+spec green (delegado) | fix typo en README |
| **T2 — Reversible módulo** | refactor con tests verdes | auto-merge + review de 1 humano | refactor interno |
| **T3 — Irreversible / datos** | migración, secrets, N3+ | review humana obligatoria + registro | touch secrets |
| **T4 — Crítico** | infra prod, auth, PII | doble humano + approval formal | política de seguridad |

### 2. Clasificador `scripts/risk-tier.sh`

- Entrada: diff metadata (archivos, keywords, paths)
- Salida: `{tier: 1-4, rationale, blocks: [...], requires_human: bool}`
- Reglas deterministas: paths (secrets/, infra/), keywords (N3+, PII, migration),
  tipos de cambio (docs-only → tier 1)

### 3. Integración con pr-plan / push-pr

- `push-pr.sh --merge` consulta `risk-tier.sh`:
  - Tier 1 delegado → permite merge sin humano (si grant vigente)
  - Tier 3/4 → bloquea sin approval humano explícito (registrado)
- La operadora delega por tier vía grant (como esta sesión)

### 4. Registro de decisiones

Cada clasificación y merge se registra en el audit ledger (SE-355) con
`outcome: enforced_allow|enforced_deny` y `gate_id: risk-tier`.

## Criterios de aceptación

- **AC-0** Clasificador asigna tier 1 a cambio docs-only (test)
- **AC-1** Clasificador asigna tier 3/4 a paths de secrets/infra (test)
- **AC-2** `push-pr.sh --merge` respeta tier (T3/4 bloqueado sin approval explícito)
- **AC-3** Cada clasificación registra receipt en SE-355 con gate_id risk-tier
- **AC-4** Fail-closed: path no clasificable → tier 3 (humano, no asume bajo riesgo)
- **AC-5** Sin regresión: autonomo-safety.md sigue siendo la capa final (humano dispone)

## OpenCode Implementation Plan

### Bindings touched
- `scripts/risk-tier.sh` (nuevo), `docs/rules/domain/risk-tiering.md` (nuevo)
- `scripts/push-pr.sh` (integración --merge), CRITERIO.md (referencia a gradación)

### Verification protocol
```bash
bats tests/bats/test-risk-tier.bats
bash scripts/risk-tier.sh --diff <files>
```

### Portability classification
- Bash + python3 stdlib; local; portable

## Validación (ejecutada en esta sesión)

- `scripts/risk-tier.py`: clasifica T1 (docs-only), T2 (código), T3 (secrets/migrations/push), T4 (infra/prod/PII), fail-closed unknown → T3; 7 pytest + 5 bats verdes
- `push-pr.sh --merge`: consulta risk-tier antes de mergear; T3/T4 bloqueado sin review humana aun con grant (SE-343)

## Referencias
- Anthropic: claude.com/blog/the-ai-native-sdlc-playbook (gobernanza ejecutable)
- Amplitude risk model (gradación por riesgo)
- Savia: CRITERIO.md (CRIT-022 reversibilidad), autonomous-safety.md, SE-355, CRIT-001
