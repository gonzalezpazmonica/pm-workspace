-- Template: audit-trigger.sql — SPEC-SE-037 Append-Only JSONB Audit Trigger
-- Full canonical SQL: audit_log table, trigger function, attach_audit procedure.
--
-- Compliance primitive: append-only audit_log + generic trigger function.
-- Adjuntable a cualquier tabla regulada. Postgres >= 14, no extensions.
--
-- AC-01 Tabla append-only (REVOKE UPDATE/DELETE)
-- AC-02 audit_trigger_fn() table-agnostic (9 campos)
-- AC-03 attach_audit(regclass) helper procedure
-- AC-04 RLS multi-tenant (SPEC-SE-002)
-- AC-11 Migration: 5 tablas reguladas
--
-- Pattern: dreamxist/balance supabase/migrations/00006_audit_log.sql (MIT, clean-room re-implementation)
-- Reference: SPEC-SE-037 (docs/propuestas/savia-enterprise/SPEC-SE-037-audit-jsonb-trigger.md)
-- Doc: docs/rules/domain/savia-enterprise/audit-trigger-primitive.md

BEGIN;

-- 1. Tabla audit_log append-only

CREATE TABLE IF NOT EXISTS audit_log (
  id           bigserial    PRIMARY KEY,
  table_name   text         NOT NULL,
  record_id    text         NOT NULL,
  operation    text         NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
  old_row      jsonb,
  new_row      jsonb,
  user_id      text,
  agent_id     text,
  session_id   text,
  tenant_id    uuid,
  created_at   timestamptz  NOT NULL DEFAULT now()
);

-- Primary query pattern: tenant + table + time range
CREATE INDEX IF NOT EXISTS audit_log_tenant_table_time
  ON audit_log (tenant_id, table_name, created_at DESC);

CREATE INDEX IF NOT EXISTS audit_log_operation_time
  ON audit_log (operation, created_at DESC);

CREATE INDEX IF NOT EXISTS audit_log_agent_time
  ON audit_log (agent_id, created_at DESC);

-- Append-only enforcement: Writers can INSERT but NEVER UPDATE or DELETE.
REVOKE UPDATE, DELETE ON audit_log FROM PUBLIC;

-- RLS multi-tenant isolation (SPEC-SE-002)
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = current_schema()
      AND tablename  = 'audit_log'
      AND policyname = 'audit_log_tenant_isolation'
  ) THEN
    CREATE POLICY audit_log_tenant_isolation ON audit_log
      USING (tenant_id::text = current_setting('savia.tenant_id', true));
  END IF;
END $$;

-- 2. Generic trigger function audit_trigger_fn()
-- Table-agnostic: captures 9 fields for every INSERT/UPDATE/DELETE.
-- Uses AFTER trigger semantics -- records the final committed state.
-- current_setting(..., true) silences missing-setting errors -> NULL default.
-- tenant_id extracted from the row itself (not from session) for integrity.

CREATE OR REPLACE FUNCTION audit_trigger_fn() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_user_id    text;
  v_agent_id   text;
  v_session_id text;
  v_tenant_id  uuid;
  v_record_id  text;
BEGIN
  BEGIN
    v_user_id := current_setting('request.jwt.claims', true)::jsonb->>'sub';
  EXCEPTION WHEN others THEN
    v_user_id := NULL;
  END;

  v_agent_id   := current_setting('savia.agent_id',   true);
  v_session_id := current_setting('savia.session_id', true);

  IF TG_OP = 'DELETE' THEN
    BEGIN v_tenant_id := (to_jsonb(OLD)->>'tenant_id')::uuid; EXCEPTION WHEN others THEN v_tenant_id := NULL; END;
    v_record_id := COALESCE(to_jsonb(OLD)->>'id', '');
  ELSE
    BEGIN v_tenant_id := (to_jsonb(NEW)->>'tenant_id')::uuid; EXCEPTION WHEN others THEN v_tenant_id := NULL; END;
    v_record_id := COALESCE(to_jsonb(NEW)->>'id', '');
  END IF;

  INSERT INTO audit_log
    (table_name, record_id, operation, old_row,  new_row,
     user_id,    agent_id,  session_id, tenant_id)
  VALUES
    (TG_TABLE_NAME,
     v_record_id,
     TG_OP,
     CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
     CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
     v_user_id,
     v_agent_id,
     v_session_id,
     v_tenant_id);

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- 3. Helper procedure: attach_audit(p_table regclass)
-- One-liner to add the audit trigger to any regulated table.
-- Usage: CALL attach_audit('tenants'::regclass);
-- Idempotent: drops existing trigger before creating.

CREATE OR REPLACE PROCEDURE attach_audit(p_table regclass)
LANGUAGE plpgsql AS $$
DECLARE
  v_trigger_name text;
BEGIN
  v_trigger_name := 'audit_' || replace(p_table::text, '.', '_');

  EXECUTE format(
    'DROP TRIGGER IF EXISTS %I ON %s',
    v_trigger_name, p_table
  );

  EXECUTE format(
    'CREATE TRIGGER %I '
    'AFTER INSERT OR UPDATE OR DELETE ON %s '
    'FOR EACH ROW EXECUTE FUNCTION audit_trigger_fn()',
    v_trigger_name, p_table
  );

  RAISE NOTICE 'audit trigger "%" attached to table %', v_trigger_name, p_table;
END;
$$;

-- 4. Attach audit trigger to regulated tables
-- Run after creating the target tables. In pm-workspace: documentation only.

CALL attach_audit('tenants'::regclass);
CALL attach_audit('projects'::regclass);
CALL attach_audit('billing_invoices'::regclass);
CALL attach_audit('agent_sessions'::regclass);
CALL attach_audit('api_keys'::regclass);

COMMIT;
