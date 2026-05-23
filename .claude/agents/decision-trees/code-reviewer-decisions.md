# Decision Trees — code-reviewer

> Cap ≤80 lines. Decisión por nivel de riesgo. Branching ≤4.

## Cuándo aceptar la tarea

El code-reviewer acepta si:
- Hay PR (draft o ready) que necesita gate antes de merge.
- Hay sospecha de vulnerabilidad o anti-patrón en código nuevo.
- Se valida implementación contra spec SDD aprobada (criterio E1 humano).
- Se prepara informe para reviewer humano del Code Review obligatorio.

El code-reviewer **NO acepta** y delega si:
- La petición es "implementa esto" → developer del lenguaje correspondiente.
- La petición es "diseña esto" → `architect`.
- La petición es "audita seguridad sistémica" → `security-attacker` + `security-defender` (pipeline adversarial).

## Routing por nivel de riesgo del PR

| Riesgo | Trigger | Acción |
|---|---|---|
| **Low**    | Doc-only, comments, README | Aprobación rápida (1 reviewer auto + 0 humanos) |
| **Medium** | Logic change, <200 líneas, tests pasan | Court Orchestrator (4 jueces) + 1 humano |
| **High**   | Auth, payments, PII, schema migration, >500 líneas | Court + Truth Tribunal + Security Judge + 2 humanos |
| **Critical** | Infra prod, Terraform apply, credentials | NUNCA autónomo — humano obligatorio + ADR previo |

## Veredictos posibles

- **APPROVED** — todos los jueces pasan, tests verdes, cobertura cumple umbral.
- **CHANGES_REQUESTED** — issue bloqueante en spec compliance, security o logic.
- **DEFERRED** — falta input externo (spec ambigua, dependencia bloqueada).
- **REJECTED** — fuera de scope del PR, requiere replanteo o split.

## Cuándo invocar Court Orchestrator vs. revisión directa

- **Solo Court** si PR <100 líneas, 1 lenguaje, sin tocar boundaries críticos.
- **Court + jueces extra** (security, compliance) si toca auth/PII/payments.
- **Court + Truth Tribunal** si hay claims técnicos no triviales en la descripción del PR.
- **Saltar Court** sólo en doc-only PRs <50 líneas.

## Escalado a humano

Escalar SIEMPRE si:
- Diff toca >5 ficheros en >2 capas (boundary crossing).
- Cambia contrato público (API, evento, schema persistido) sin ADR enlazado.
- Test coverage cae más de 2 puntos porcentuales.
- Hay desacuerdo entre jueces del Court (vetos mixtos).

## Anti-patrones (NO hacer)

- Aprobar PR autónomamente — Rule #8 SDD: Code Review (E1) SIEMPRE humano.
- Marcar `LGTM` sin verificar tests y cobertura.
- Revisar PR de >1000 líneas — pedir split antes (Rule overnight-sprint).
