-- reconciliation.sql — Reference template for SPEC-SE-035
--
-- Tenant-level invariant function: declared vs computed value with 3-tier
-- status (green / amber / red). Reusable across knowledge federation,
-- billing, capacity. Patrón importado de Balance (MIT) — re-implementación.
--
-- Reference: dreamxist/balance supabase/migrations/00009_reconciliation.sql

BEGIN;

-- Registry of reconcilable dimensions. Each row defines:
--   - declared_query: SQL returning (tenant_id, value::numeric)
--   - computed_query: SQL returning (tenant_id, value::numeric)
-- Function tenant_reconciliation_status() computes delta = declared - computed
-- and emits the tier.
CREATE TABLE IF NOT EXISTS reconciliation_dimensions (
  dimension       text PRIMARY KEY,
  declared_query  text NOT NULL,
  computed_query  text NOT NULL,
  amber_threshold numeric NOT NULL DEFAULT 1000,
  red_threshold   numeric NOT NULL DEFAULT 5000,
  active          boolean DEFAULT true,
  created_at      timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now()
);

-- Reconciliation alerts (writes from the reconciliation_status trigger when
-- tier transitions to amber/red). Append-only contract with audit-log Slice.
CREATE TABLE IF NOT EXISTS reconciliation_alerts (
  id          bigserial PRIMARY KEY,
  tenant_id   uuid NOT NULL,
  dimension   text NOT NULL,
  declared    numeric,
  computed    numeric,
  delta       numeric,
  tier        text NOT NULL CHECK (tier IN ('green','amber','red')),
  alerted_at  timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS reconciliation_alerts_recent
  ON reconciliation_alerts (tenant_id, dimension, alerted_at DESC);

-- Core function: returns JSONB with delta + tier
CREATE OR REPLACE FUNCTION tenant_reconciliation_status(
  p_tenant_id uuid,
  p_dimension text
) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_dim         reconciliation_dimensions%ROWTYPE;
  v_declared    numeric;
  v_computed    numeric;
  v_delta       numeric;
  v_tier        text;
BEGIN
  SELECT * INTO v_dim FROM reconciliation_dimensions
    WHERE dimension = p_dimension AND active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'unknown dimension', 'dimension', p_dimension);
  END IF;

  -- Run the parametrised queries. They MUST return one row with a numeric column.
  EXECUTE format('SELECT value FROM (%s) q WHERE tenant_id = $1', v_dim.declared_query)
    INTO v_declared USING p_tenant_id;
  EXECUTE format('SELECT value FROM (%s) q WHERE tenant_id = $1', v_dim.computed_query)
    INTO v_computed USING p_tenant_id;

  v_declared := COALESCE(v_declared, 0);
  v_computed := COALESCE(v_computed, 0);
  v_delta    := v_declared - v_computed;

  v_tier := CASE
    WHEN abs(v_delta) >= v_dim.red_threshold   THEN 'red'
    WHEN abs(v_delta) >= v_dim.amber_threshold THEN 'amber'
    ELSE 'green'
  END;

  RETURN jsonb_build_object(
    'tenant_id',  p_tenant_id,
    'dimension',  p_dimension,
    'declared',   v_declared,
    'computed',   v_computed,
    'delta',      v_delta,
    'tier',       v_tier,
    'checked_at', now()
  );
END;
$$;

-- Materialised view: one row per (tenant, dimension) with current tier.
-- Refresh CONCURRENTLY for non-blocking updates.
CREATE MATERIALIZED VIEW IF NOT EXISTS tenant_reconciliation_dashboard AS
SELECT
  tr.tenant_id,
  rd.dimension,
  (tenant_reconciliation_status(tr.tenant_id, rd.dimension)) AS status,
  ((tenant_reconciliation_status(tr.tenant_id, rd.dimension))->>'tier') AS tier
FROM (SELECT DISTINCT id AS tenant_id FROM tenants) tr
CROSS JOIN reconciliation_dimensions rd
WHERE rd.active = true;

CREATE UNIQUE INDEX IF NOT EXISTS tenant_reconciliation_dashboard_pk
  ON tenant_reconciliation_dashboard (tenant_id, dimension);

COMMIT;

-- Seed: 4 default dimensions (uncomment + adjust queries to match your schema)
-- INSERT INTO reconciliation_dimensions (dimension, declared_query, computed_query, amber_threshold, red_threshold) VALUES
--   ('backlog_sp',
--    'SELECT id AS tenant_id, declared_backlog_sp AS value FROM tenants',
--    'SELECT tenant_id, sum(estimate_sp) AS value FROM pbis GROUP BY tenant_id',
--    5, 20),
--   ('budget',
--    'SELECT id AS tenant_id, contracted_budget AS value FROM tenants',
--    'SELECT tenant_id, sum(hours * rate) AS value FROM hours_ledger GROUP BY tenant_id',
--    1000, 5000),
--   ('capacity',
--    'SELECT id AS tenant_id, declared_capacity_hours AS value FROM tenants',
--    'SELECT tenant_id, sum(assigned_hours) AS value FROM resource_assignments GROUP BY tenant_id',
--    20, 80),
--   ('knowledge_catalog_hash',
--    'SELECT id AS tenant_id, encode(declared_catalog_hash, ''hex'')::numeric AS value FROM tenants',
--    'SELECT tenant_id, encode(computed_catalog_hash, ''hex'')::numeric AS value FROM federated_knowledge_view',
--    0, 1);
