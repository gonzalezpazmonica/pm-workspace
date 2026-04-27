---
status: PROPOSED
---

# SPEC-SE-037: Append-Only JSONB Audit Trigger as Compliance Primitive

> **Estado**: Draft — Roadmap Era 232
> **Prioridad**: P1 (Compliance baseline — más barata, mejor ROI)
> **Dependencias**: SPEC-SE-006 (governance-compliance), SPEC-SE-026 (compliance-evidence)
> **Era**: 232
> **Inspiración**: `dreamxist/balance` `supabase/migrations/00006_audit_log.sql` —
> `audit_trigger_fn()` genérico capturando `{table_name, record_id, operation,
> old_row, new_row, user_id, created_at}` desde JWT sub claim. Append-only por
> schema constraint.

---

## Problema

SPEC-SE-026 (compliance-evidence) define **qué evidence** recolectar. SPEC-SE-006
(governance-compliance) define **qué políticas**. Ninguno especifica un
**capture primitive reusable, table-agnostic**: hoy cada skill que necesita
evidencia auditable tiene su propia lógica de logging, formato y storage.

Manifestaciones del problema:

- 3 skills diferentes (audit-trail, audit-export, audit-search) escriben a
  3 tablas con schemas distintos
- Tablas regulated nuevas (compliance scenarios ISO-42001, EU AI Act, GDPR
  Article 30) requieren código repetido por cada superficie
- Drift entre "lo que la skill registra" y "lo que la regulación exige"
  porque cada autor decide qué guardar

**Cost of inaction**: cada nueva tabla regulada en Savia Enterprise multiplica
el esfuerzo de compliance linealmente. Con 30+ tablas en multi-tenant + billing
+ projects + agents, el coste acumulado de mantener evidencia auditable a mano
es prohibitivo.

## Tesis

Un único trigger function genérico `audit_trigger_fn()` adjuntable a cualquier
tabla regulada captura automáticamente:

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
  "created_at": "..."
}
```

en una tabla `audit_log` append-only por constraint (no DELETE, no UPDATE permitido
salvo retention purge documentado). Una sola línea de código por tabla
regulada (`CREATE TRIGGER ... EXECUTE FUNCTION audit_trigger_fn()`), evidencia
ISO-42001 / EU AI Act / GDPR Article 30 automáticamente.

## Scope (slice único, S 6-8h)

### 1. Tabla append-only

```sql
CREATE TABLE audit_log (
  id bigserial PRIMARY KEY,
  table_name text NOT NULL,
  record_id text NOT NULL,
  operation text NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
  old_row jsonb,
  new_row jsonb,
  user_id text,                  -- desde jwt.claims.sub
  agent_id text,                 -- desde savia.agent_id (settable per session)
  session_id text,
  tenant_id uuid,                -- desde row si tiene tenant_id, else NULL
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX audit_log_tenant_table_time
  ON audit_log (tenant_id, table_name, created_at DESC);

-- Append-only enforcement: no UPDATE, no DELETE except via documented retention purge
REVOKE UPDATE, DELETE ON audit_log FROM PUBLIC;

-- RLS multi-tenant (SPEC-SE-002)
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY audit_log_tenant_isolation ON audit_log
  USING (tenant_id = current_setting('savia.tenant_id', true)::uuid);
```

### 2. Trigger function genérico

```sql
CREATE OR REPLACE FUNCTION audit_trigger_fn() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_user_id text := current_setting('request.jwt.claims', true)::jsonb->>'sub';
  v_agent_id text := current_setting('savia.agent_id', true);
  v_session_id text := current_setting('savia.session_id', true);
  v_tenant_id uuid;
  v_record_id text;
BEGIN
  -- Extract tenant_id and record_id from row dynamically
  IF TG_OP = 'DELETE' THEN
    v_tenant_id := (to_jsonb(OLD)->>'tenant_id')::uuid;
    v_record_id := (to_jsonb(OLD)->>'id');
  ELSE
    v_tenant_id := (to_jsonb(NEW)->>'tenant_id')::uuid;
    v_record_id := (to_jsonb(NEW)->>'id');
  END IF;

  INSERT INTO audit_log
    (table_name, record_id, operation, old_row, new_row,
     user_id, agent_id, session_id, tenant_id)
  VALUES
    (TG_TABLE_NAME, v_record_id, TG_OP,
     CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
     CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
     v_user_id, v_agent_id, v_session_id, v_tenant_id);

  RETURN COALESCE(NEW, OLD);
END;
$$;
```

### 3. Helper macro para attach

```sql
CREATE OR REPLACE PROCEDURE attach_audit(p_table regclass) AS $$
BEGIN
  EXECUTE format(
    'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON %s '
    'FOR EACH ROW EXECUTE FUNCTION audit_trigger_fn()',
    'audit_' || p_table::text, p_table);
END;
$$ LANGUAGE plpgsql;

-- Usage: CALL attach_audit('tenants'::regclass);
```

### 4. Retention + purge documentation

Append-only NO significa "infinito". GDPR Article 30 obliga retention finita.
Doc define ventanas por table_name:

| Categoría | Retention | Justificación |
|---|---|---|
| Compliance evidence (ISO-42001) | 5 years | ISO-42001 Annex A audit retention |
| Billing / project / contract | 10 years | Tax + commercial law (EU) |
| Agent activity / session log | 90 days | Operational; nothing personal |
| User actions on personal data | 3 years | GDPR Art. 30, recital 82 |

Purge job (`bash scripts/enterprise/audit-purge.sh --before <date> --table <name>
--confirm`) requires `--confirm` flag, logs pre-purge count, refuses to run
without explicit retention policy in `docs/rules/domain/savia-enterprise/audit-retention.md`.

### 5. Tests + CLI inspector

```bash
bash scripts/enterprise/audit-search.sh --tenant <id> --table tenants --since 7d
```

Output: tabular listing of changes with diff column (computed from old_row vs new_row).

## Acceptance criteria

- [ ] AC-01 Tabla `audit_log` append-only (REVOKE UPDATE/DELETE)
- [ ] AC-02 Función `audit_trigger_fn()` table-agnostic capturando 9 campos
- [ ] AC-03 Procedure `attach_audit(regclass)` para agregar a tabla nueva
- [ ] AC-04 RLS multi-tenant respetado (SPEC-SE-002)
- [ ] AC-05 Doc retention policy en `audit-retention.md` con tabla por categoría
- [ ] AC-06 CLI `audit-search.sh` con filter tenant/table/agent/since
- [ ] AC-07 CLI `audit-purge.sh` requires --confirm + retention policy file
- [ ] AC-08 Tests pgTAP ≥8 (trigger behavior) + BATS ≥6 score ≥80 (CLI)
- [ ] AC-09 SQL template `docs/propuestas/savia-enterprise/templates/audit-trigger.sql`
- [ ] AC-10 Doc `docs/rules/domain/savia-enterprise/audit-trigger-primitive.md`
- [ ] AC-11 Migration: attach_audit a 5 tablas regulated existentes (tenants, projects, billing_invoices, agent_sessions, api_keys)
- [ ] AC-12 CHANGELOG entry

## No hace

- NO sustituye SPEC-SE-026 compliance-evidence — la integra con un primitive
- NO promete retention infinita: doc define ventanas finitas por categoría
- NO añade dependencia Supabase: SQL puro Postgres ≥14
- NO cifra el `audit_log` (esto es Era 233+: SPEC-SE-XX field-level encryption)
- NO captura SELECT (sólo INSERT/UPDATE/DELETE — SELECT auditing es otro spec)

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| audit_log explota en disco | Alta | Medio | Retention purge + table partitioning by month |
| Trigger overhead en write-heavy tables | Media | Medio | Trigger AFTER (no BEFORE), JSONB cast lazy |
| `current_setting()` empty rompe trigger | Media | Bajo | `true` arg en current_setting silencia missing; defaults NULL |
| Drift entre row.tenant_id real y `savia.tenant_id` setting | Baja | Alto | Defensa en profundidad: SPEC-SE-035 reconcile flagea drift |

## Dependencias

- **Bloquea**: nada
- **Habilita**: SPEC-SE-006 governance-compliance, SPEC-SE-026 compliance-evidence
- **Sinergia**: SPEC-SE-036 api-keys (auditadas automáticamente al attach), SPEC-SE-035 reconciliation (audit_log para forensics post-drift)
- **Independiente**: SPEC-SE-002 multi-tenant (asumido stable)

## Referencias

- `dreamxist/balance` `supabase/migrations/00006_audit_log.sql` (origen pattern)
- SPEC-SE-026 compliance-evidence (consumidor)
- SPEC-SE-006 governance-compliance (consumidor)
- ISO-42001 Annex A audit retention requirements
- EU AI Act Art. 12 record-keeping
- GDPR Art. 30 records of processing activities
- License compatibility: Balance MIT — re-implement, no import wholesale
