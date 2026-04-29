---
status: IN_PROGRESS
---

# SPEC-SE-035: Reconciliation Delta Engine for Federated Knowledge

> **Estado**: Draft — Roadmap Era 232
> **Prioridad**: P2 (Federation hardening)
> **Dependencias**: SPEC-SE-023 (knowledge-federation), SPEC-SE-018 (project-billing), SPEC-SE-022 (resource-bench)
> **Era**: 232
> **Inspiración**: `dreamxist/balance` `supabase/migrations/00009_reconciliation.sql` —
> `get_reconciliation_status()` JSONB con tier verde/ámbar/rojo (delta=0 / <1000 / ≥1000).
> Patrón: posición real == suma de transacciones; delta cero o se arregla en el día.

---

## Problema

SPEC-SE-023 (knowledge-federation) define lecturas federadas pero **no** un
detector de drift entre el estado **declarado** y el estado **computado**.

Ejemplos de drift que hoy son invisibles hasta cierre de Q:

| Estado declarado | Estado computado | Drift hoy |
|---|---|---|
| Backlog SP del cliente (header) | Suma de PBI estimates | Manual, fin de Q |
| Headcount declarado (contrato) | Asignaciones activas vs. capacity | Manual, mensual |
| Budget proyecto (firmado) | Suma de hours ledger × tarifa | Mensual, descalibrado |
| Roadmap items prometidos | Items entregados + en-flight | Quarterly review |
| KPIs de OKR | Métricas computadas en runtime | Trimestral |

**Cost of inaction**: silent organisational drift acumula hasta que un cliente
descubre el desajuste, normalmente en una review trimestral incómoda. Cada
unidad de drift sin detectar es un riesgo de credibilidad o de margen.

Balance enseña la disciplina opuesta: **el sistema se niega a mentir sobre el
dinero**. Cada peso está localizado y explicado; si el delta entre posición real
y suma de transacciones no es cero, el balance se bloquea. Esa misma disciplina
trasplantada a portfolio health convierte el drift silencioso en una alerta
del mismo día.

## Tesis

Generalizar el patrón position-vs-accumulated de Balance en una **invariant
function tenant-level** reusable across:

- Knowledge federation (SPEC-SE-023): declared vs computed catalog hashes
- Billing (SPEC-SE-018): declared budget vs ledgered hours × rate
- Resource bench (SPEC-SE-022): declared capacity vs assigned utilisation
- Cualquier futuro componente con estado declarado vs computado

## Scope (4 slices)

### Slice 1 (S, 4h) — Primitive `tenant_reconciliation_status()`

Función Postgres genérica:

```sql
CREATE OR REPLACE FUNCTION tenant_reconciliation_status(
  p_tenant_id uuid,
  p_dimension text,                     -- 'backlog_sp' | 'budget' | 'capacity' | ...
  p_amber_threshold numeric DEFAULT 1000,
  p_red_threshold  numeric DEFAULT 5000
) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
  -- Returns:
  -- {"tenant_id": ..., "dimension": ..., "declared": <num>, "computed": <num>,
  --  "delta": <num>, "tier": "green"|"amber"|"red", "checked_at": ...}
$$;
```

Resolver `declared` y `computed` via per-dimension dispatch tables (ver Slice 2).

### Slice 2 (M, 6h) — Dispatch registry per dimension

Registro de dimensiones reconciliables:

```sql
CREATE TABLE reconciliation_dimensions (
  dimension text PRIMARY KEY,           -- 'backlog_sp', 'budget', etc.
  declared_query text NOT NULL,         -- SQL devolviendo (tenant_id, value)
  computed_query text NOT NULL,         -- SQL devolviendo (tenant_id, value)
  amber_threshold numeric NOT NULL,
  red_threshold  numeric NOT NULL,
  active boolean DEFAULT true
);
```

Seed inicial: 4 dimensiones (backlog_sp, budget, capacity, knowledge_catalog_hash).
Enterprise tenants añaden las suyas vía Slice 4.

### Slice 3 (S, 3h) — `tenant_reconciliation_dashboard` view

Vista materializada refrescada async (`pg_cron` opcional, default trigger
on-write a tablas relevantes). Output: una fila por (tenant, dimensión) con
tier coloreado.

CLI wrapper en pm-workspace: `bash scripts/enterprise/reconciliation-status.sh
<tenant>` ejecuta la query y formatea como tabla colored ANSI (verde/ámbar/rojo).

### Slice 4 (M, 4h) — Webhook + alerting

- Trigger `AFTER UPDATE OR INSERT` en tablas declarativas (e.g., `tenant_budget`)
  que recomputa el status para esa (tenant, dimension)
- Si tier transitions a `amber` o `red`, escribe a `reconciliation_alerts` table
- Webhook outbound (configurable) a Slack/Teams/Nextcloud Talk (existing
  channel infra de SPEC-SE-024 client-health)

### Slice 5 — Ratchet baseline

`.ci-baseline/reconciliation-tier-counts.json` registra el número de tenants
en cada tier (green/amber/red) por dimensión. CI compara baseline tras cada
release: si `red` count regresa, bloquea merge (mismo pattern que
hook-coverage ratchet).

## Acceptance criteria

- [ ] AC-01 Función `tenant_reconciliation_status()` definida con 3 tiers
- [ ] AC-02 4 dimensiones seed (backlog_sp, budget, capacity, knowledge_catalog_hash)
- [ ] AC-03 Vista materializada `tenant_reconciliation_dashboard` con tier coloreado
- [ ] AC-04 CLI `reconciliation-status.sh <tenant>` con output ANSI
- [ ] AC-05 Trigger recompute on-write con webhook opcional
- [ ] AC-06 Baseline ratchet bloquea regresión en `red` count
- [ ] AC-07 Tests pgTAP ≥10 (Postgres) + BATS ≥8 score ≥80 (CLI)
- [ ] AC-08 Doc `docs/rules/domain/savia-enterprise/reconciliation-delta-engine.md`
- [ ] AC-09 SQL template en `docs/propuestas/savia-enterprise/templates/reconciliation.sql`
- [ ] AC-10 CHANGELOG entry

## No hace

- NO sustituye SPEC-SE-018 billing — la integra
- NO redefine RLS multi-tenant (asume SPEC-SE-002 estable)
- NO añade dependencia Supabase: SQL puro Postgres ≥14, pg_cron opcional
- NO inventa thresholds — son configurables per dimension, defaults conservadores
- NO escribe a sistemas externos sin webhook explícito en config

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Triggers recursivos (recompute → write → recompute) | Media | Alto | `pg_advisory_lock` + flag `_in_reconciliation` en sesión |
| Vista materializada explota con N tenants × M dimensiones | Baja | Medio | Refresh selectivo by tenant; CONCURRENTLY |
| Falsos amber por timing (write vs read race) | Media | Bajo | Re-check on amber; sólo alerta tras 2 lecturas consecutivas |
| Webhook abuse en cascade de cambios | Media | Medio | Rate-limit per (tenant, dimension): max 1 alerta/15min |

## Dependencias

- **Bloquea**: nada
- **Habilita**: SPEC-SE-024 client-health (cross-tenant rollup), SPEC-SE-018 billing alerts
- **Sinergia**: SPEC-SE-022 resource-bench (capacity dimension reusa primitive)
- **Independiente**: SPEC-SE-006 governance-compliance (este enforce, ése audita)

## Referencias

- `dreamxist/balance` `supabase/migrations/00009_reconciliation.sql` (origen pattern)
- SPEC-SE-023 knowledge-federation (consumidor)
- SPEC-SE-018 project-billing (consumidor)
- SPEC-SE-022 resource-bench (consumidor)
- SPEC-SE-024 client-health (consumidor cross-tenant)
- License compatibility: Balance MIT — re-implement, no import wholesale
