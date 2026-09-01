# SE-359 — REVIEW.md policy: passes canónicos, severidad cerrada y cap de nits

**Status:** APPROVED (2026-08-31, operadora grant merge sesión nocturna)
**Fecha:** 2026-08-31
**Área:** Review / Governance
**Fuente de inspiración:** Anthropic AI-Native SDLC Playbook (Stage 5 — AI in the PR review loop, REVIEW.md)
**Criterio humano aplicable:** CRIT-001

---

## Objetivo

Crear `REVIEW.md` como **política canónica de review** para el Code Review Court
de Savia: define los passes que el court ejecuta (bugs/security/compliance),
normaliza la severidad (Important vs Nit) con vocabulario cerrado, limita el
volumen de nits (cap 5, resto como count), y excluye explícitamente lo que CI ya
enforce. El court lee REVIEW.md como entrada al igual que la spec.

## Contexto

El playbook de Anthropic propone `REVIEW.md` en la raíz del repo: "dividido en
los passes que la organización cuida: bugs y errores lógicos; seguridad y
vulnerabilidades; compliance contra la spec, el plan y principios de diseño.
REVIEW.md también define qué cuenta como Important vs Nit, y qué saltar." Verificado
en Savia: el Code Review Court tiene 8 judges (correctness, security, cognitive,
architecture, spec...) pero **no hay una REVIEW.md canónica** — la severidad y el
volumen de findings dependen del prompt de cada judge, no de una política
versionada. Gap: reviews inconsistentes entre judges y sesiones, sin cap de nits.

**Rechazo explícito (CRIT-001):** REVIEW.md es un fichero local versionado; el
court corre local. Sin servicio externo.

## Diseño

### 1. `REVIEW.md` canónico (raíz del repo)

```markdown
# Review instructions

## Passes
Run three passes and tag each finding with its pass:
- Bugs: logic errors, broken edge cases, subtle regressions
- Security: injection risks, authentication gaps, PII in logs
- Compliance: the change matches spec.md, plan.md and design principles

## What Important means here
Reserve Important for findings that would break behavior, leak data or breach a policy.
Style and naming are nits.

## Cap the nits
Report at most five nits per review; summarize the rest as a count.

## Do not report
Generated files and anything CI already enforces.
```

### 2. Parser `scripts/review-policy-parse.py`

- Lee REVIEW.md, extrae passes, severidad, cap de nits, exclusiones
- Salida JSON consumible por el court

### 3. Integración con court

- `court-orchestrator` carga REVIEW.md al arrancar
- Cada judge recibe el vocabulario cerrado de severidad (Important/Nit) y el cap
- El consolidado respeta el cap de nits (primeros 5 con detalle, resto count)

## Criterios de aceptación

- **AC-0** Parser extrae passes/severidad/cap/exclusiones de REVIEW.md canónico (test)
- **AC-1** Court consolida con cap de nits aplicado (≤5 detallados, resto count)
- **AC-2** Vocabulario cerrado: finding con severidad no listada → warning + downgrade a Nit
- **AC-3** Exclusiones (generados/CI-enforced) no aparecen en el consolidado
- **AC-4** REVIEW.md ausente → court usa defaults (no rompe)
- **AC-5** Sin regresión: suite del court existente verde

## OpenCode Implementation Plan

### Bindings touched
- `REVIEW.md` (nuevo, raíz), `scripts/review-policy-parse.py` (nuevo)
- `court-orchestrator` prompt (carga REVIEW.md), judges (vocabulario severidad)

### Verification protocol
```bash
bats tests/bats/test-review-policy.bats
python3 scripts/review-policy-parse.py --file REVIEW.md
```

### Portability classification
- Bash + python3 stdlib; local; portable
## Validación (ejecutada en esta sesión)

- `REVIEW.md` en raíz con 3 passes + vocab cerrado (Important|Nit) + cap 5 nits + exclusiones
- `review-policy-parse.py`: extrae política a JSON; fail-soft con REVIEW.md ausente; 7 pytest + 7 bats verdes

## Referencias

- Anthropic: claude.com/blog/the-ai-native-sdlc-playbook (Stage 5, REVIEW.md)
- Savia: Code Review Court (court-orchestrator, 8 judges), CRIT-001
