# Regla: Append-Only Audit Trigger — primitive de compliance reusable

> **Era 232** — Savia Enterprise Balance Extensions. Pattern source: `dreamxist/balance` `supabase/migrations/00006_audit_log.sql` (MIT, clean-room re-implementation, no wholesale import).
>
> **Estado**: `IMPLEMENTED 2026-04-28` (templates + CLI + rule doc en pm-workspace; migrations a tablas reales DEFERRED al repo Savia Enterprise).

## Por qué

SPEC-SE-026 (compliance-evidence) define **qué evidencia** recolectar. SPEC-SE-006 (governance-compliance) define **qué políticas**. Hoy cada skill que necesita evidencia auditable tiene su propio formato y storage:

- `audit-trail`, `audit-export`, `audit-search` skills → 3 schemas distintos
- Tablas regulatedas nuevas (ISO-42001, EU AI Act, GDPR Art. 30) requieren código repetido
- Drift entre lo que la skill registra y lo que la regulación exige

Coste de no centralizar: cada nueva tabla regulada multiplica linealmente el esfuerzo. Con 30+ tablas en multi-tenant + billing + projects + agents, mantener evidencia auditable a mano es prohibitivo.

## Tesis

Un único trigger function genérico `audit_trigger_fn()` adjuntable a cualquier tabla regulada captura automáticamente:

```jsonb
{
  "table_name": "tenants",
  "record_id": "...",
  "operation": "UPDATE",
  "old_row": {...},
  "new_row": {...},
  "user_id": "<from current_setting('jwt.claims.sub')>",
  "agent_id": "<from current_setting('savia.agent_id', true)>",
  "session_id": "...",
  "tenant_id": "<from row's tenant_id column>",
  "created_at": "..."
}
```

en una tabla `audit_log` append-only por constraint. Una sola línea (`CALL attach_audit('your_table'::regclass)`) basta para que cualquier tabla regulada tenga evidencia ISO-42001 / EU AI Act / GDPR Art. 30 automáticamente.

## Componentes en pm-workspace

| Artefacto | Path | Rol |
|---|---|---|
| Template SQL canónico | `docs/propuestas/savia-enterprise/templates/audit-trigger.sql` | Fuente de la migration. Aplicar al repo Enterprise tal cual. |
| CLI inspector | `scripts/enterprise/audit-search.sh` | Búsqueda interactiva sobre el `audit_log`. Filtros: tenant / table / agent / since. |
| CLI purge | `scripts/enterprise/audit-purge.sh` | Borrado selectivo con `--confirm`. Refuses sin retention policy file. |
| Retention policy | `docs/rules/domain/savia-enterprise/audit-retention.md` | Ventanas finitas por categoría regulatoria. |
| Rule canónica | `docs/rules/domain/savia-enterprise/audit-trigger-primitive.md` | Este doc. |
| Tests BATS | `tests/structure/test-audit-trigger-primitive.bats` | Verifica template + CLI + docs. |

## Reglas operativas

### 1. Append-only por constraint

```sql
REVOKE UPDATE, DELETE ON audit_log FROM PUBLIC;
```

Sólo el rol `audit_purge` (con grant explícito) puede DELETE, y solo desde el script `audit-purge.sh` que exige `--confirm` y retention policy file presente.

### 2. Multi-tenant RLS (SPEC-SE-002)

`audit_log` tiene `tenant_id` column + RLS policy que filtra por `current_setting('savia.tenant_id', true)`. Defensa en profundidad: si el setting no está, el caller no ve nada — fail-closed.

### 3. Trigger sólo AFTER (no BEFORE)

El trigger NO valida ni modifica la operación; sólo registra el resultado final. Si falla la inserción en `audit_log`, la operación original también falla — atómico.

### 4. JSON cast lazy en DELETE

En DELETE no hay NEW; en INSERT no hay OLD. El template usa CASE para evitar `to_jsonb(NULL)` calls.

### 5. Retention policy obligatoria

`scripts/enterprise/audit-purge.sh` se niega a correr si `docs/rules/domain/savia-enterprise/audit-retention.md` no existe en el repo. Esto previene "purgar sin política documentada" — un patrón clásico de incident GDPR.

### 6. CLI filtros mínimos

`audit-search.sh` debe soportar como mínimo: `--tenant <uuid>`, `--table <name>`, `--agent <id>`, `--since <duration|date>`. Output tabular con diff column (computado de `old_row` vs `new_row`).

## Por qué AFTER y no BEFORE

| Trigger | Pro | Con |
|---|---|---|
| BEFORE | Puede vetar la operación | Acopla audit con validación; si la audit falla, la op falla aunque debería succeed |
| AFTER (elegido) | Audit refleja la realidad post-operación | Si row fue rolled-back por otro trigger, audit también rolls back (correcto) |

## Por qué tenant_id desde la row

```sql
v_tenant_id := (to_jsonb(NEW)->>'tenant_id')::uuid;
```

NO se usa `current_setting('savia.tenant_id')` para `audit_log.tenant_id` porque puede haber drift entre setting y row real. Defensa en profundidad: SPEC-SE-035 reconcile flagea cuando setting != row.

## Por qué `current_setting(..., true)`

El segundo arg `true` silencia el error si el setting no está. El trigger no falla por settings missing; defaults a NULL. Esto permite que el trigger funcione en contextos sin sesión-Savia (e.g., admin scripts).

## Cross-references

- SPEC-SE-037 spec — `docs/propuestas/savia-enterprise/SPEC-SE-037-audit-jsonb-trigger.md`
- SPEC-SE-002 multi-tenant RLS — patrón heredado
- SPEC-SE-006 governance-compliance — consumidor
- SPEC-SE-026 compliance-evidence — consumidor
- SPEC-SE-035 reconciliation — flagea drift entre setting y row

## Limitaciones conocidas

- NO captura SELECT (sólo INSERT/UPDATE/DELETE — SELECT auditing requiere otro spec, e.g. via pgaudit extension).
- NO cifra el `audit_log` (esto es Era 233+ field-level encryption).
- NO maneja particiones automáticas — para tablas write-heavy, partitioning por mes es responsabilidad del DBA.
- En pm-workspace los CLI fallan graceful sin `SAVIA_ENTERPRISE_DSN` configurado — la lógica DB-bound se valida en el repo Enterprise post-migration.

## Referencias

- `dreamxist/balance` `supabase/migrations/00006_audit_log.sql` — pattern source (MIT)
- ISO-42001 Annex A — audit retention requirements
- EU AI Act Art. 12 — record-keeping
- GDPR Art. 30 — records of processing activities
- License compatibility: Balance MIT — re-implement, no import wholesale
