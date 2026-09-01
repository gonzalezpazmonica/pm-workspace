# SE-355 — Audit Ledger Metadata-Only + Decision Receipts con `enforced`

**Status:** APPROVED (2026-08-31, operadora grant merge sesión nocturna)
**Fecha:** 2026-08-31
**Área:** Auditoría / Compliance / Observabilidad
**Fuente de inspiración:** OpenClaw 2.0 (audit ledger: identidad, orden, acción, outcome; never stores prompts/bodies; decision receipts con `enforced`)
**Criterio humano aplicable:** CRIT-001 (local-first, sin egress)

---

## Objetivo

Auditar y endurecer el ledger de acciones de Savia para que cumpla las
propiedades del audit ledger de OpenClaw: (1) **metadata-only** — identidad,
orden, acción y outcome, **jamás** prompts, bodies, argumentos ni filenames;
(2) **decision receipts con vocabulario cerrado** donde `enforced` marca
decisiones que un gate realmente gobernó (un éxito desnudo nunca se promueve a
prueba de autorización); (3) **retention explícita** y documentación honesta de
límites ("absence of a row proves nothing").

## Contexto

Verificado en esta sesión: `session-action-log.sh` registra acciones de
agentes, pero **no verificamos que nunca persista prompts/PII**, y no hay
campo `enforced` que distinga una decisión gobernada por un gate de un éxito
sin gate. OpenClaw publica además "non-claims" explícitos (pseudonimización ≠
anonimización, ausencia de fila no prueba nada) — Savia tiene ese ethos en
`radical-honesty.md` pero no en su infraestructura de auditoría.

**Rechazo explícito (CRIT-001):** no se exporta telemetría a SIEM cloud ni a
ningún proveedor. Ledger 100% local en `data/audit/`. OTel opcional local-only.

## Diseño

### 1. Schema audit (JSONL append-only)

`data/audit/actions.jsonl`:

| Campo | Tipo | Nota |
|---|---|---|
| `ts` | ISO-8601 | |
| `session_id` | string | |
| `actor` | string | identidad (humano/agente) |
| `action` | string | verbo cerrado (`commit`, `push`, `pr_create`, `pr_merge`, `gate_deny`…) |
| `outcome` | string | `enforced_deny\|enforced_allow\|success\|failure` |
| `enforced` | boolean | true si un gate de código gobernó la decisión |
| `gate_id` | string \| null | identificador del gate (ej: `G13-scope-trace`) |
| `seq` | int | orden global (monótono) |

**Prohibido en ledger:** prompts, bodies, args, filenames, valores de secrets.

### 2. Receipts con vocabulario cerrado

- `enforced: true` solo cuando un hook/gate determinista bloqueó o aprobó la acción
- Un `outcome: success` sin gate que lo gobernó → `enforced: false` y **nunca**
  se promueve a prueba de autorización
- Script `scripts/audit-receipts.sh`: `write`, `query --actor`, `query --gate`

### 3. Retention

- Queries con cutoff de 30 días por defecto (flag `--all` para auditoría)
- Pruning en batch, no línea-a-línea
- Docs: sección "Non-claims" en `docs/rules/domain/audit-non-claims.md`

## Criterios de aceptación

- **AC-0** Schema validado: ningún registro con prompts/bodies/args (test de shape)
- **AC-1** Receipt con `enforced:false` no aparece en queries de "decisiones gobernadas"
- **AC-2** Gate real (ej. permission-mode SE-354) escribe receipt `enforced:true` con `gate_id`
- **AC-3** Query con cutoff 30d por defecto (test)
- **AC-4** Pruning batch no borra filas no-expirables (test)
- **AC-5** Sin regresión: `session-action-log.sh` sigue funcionando (compat backward)
- **AC-6** Doc de non-claims publicado y citado por el ledger

## OpenCode Implementation Plan

### Bindings touched
- `scripts/audit-receipts.sh` (nuevo), `scripts/session-action-log.sh` (extensión schema)
- `docs/rules/domain/audit-non-claims.md` (nuevo)
- Gates existentes (SE-266, SE-354, pr-plan) escriben receipts

### Verification protocol
```bash
bats tests/bats/test-audit-receipts.bats
pytest tests/scripts/test_audit_schema.py -q
bash scripts/audit-receipts.sh query --gate G13-scope-trace --days 7
```

### Portability classification
- Bash + python3 stdlib; local; portable

## Trabajo futuro (fuera de scope)
- OTel export local-only — opcional
- Signed receipts (HMAC) — extensión futura

## Referencias
- OpenClaw: `docs/start/why-openclaw.md` (Provenance: audit ledger, decision receipts, non-claims)
- Savia: `radical-honesty.md`, SE-266, SE-349 (ledger), CRIT-001
