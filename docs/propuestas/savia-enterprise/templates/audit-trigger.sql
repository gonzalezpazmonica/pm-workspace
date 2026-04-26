-- audit-trigger.sql — Reference template for SPEC-SE-037
--
-- Append-only JSONB audit trigger. Adjuntable a cualquier tabla regulada con:
--   CALL attach_audit('your_table'::regclass);
--
-- Asume Postgres ≥14, multi-tenant via current_setting('savia.tenant_id'),
-- JWT user via current_setting('request.jwt.claims').sub.
--
-- Reference: dreamxist/balance supabase/migrations/00006_audit_log.sql (MIT)
-- Re-implementación; no wholesale import.

BEGIN;

CREATE TABLE IF NOT EXISTS audit_log (
  id           bigserial PRIMARY KEY,
  table_name   text NOT NULL,
  record_id    text NOT NULL,
  operation    text NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
  old_row      jsonb,
  new_row      jsonb,
  user_id      text,
  agent_id     text,
  session_id   text,
  tenant_id    uuid,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS audit_log_tenant_table_time
  ON audit_log (tenant_id, table_name, created_at DESC);

-- Append-only: writers can INSERT (via trigger) but not UPDATE / DELETE.
-- Retention purge runs as a separate role with explicit grant.
REVOKE UPDATE, DELETE ON audit_log FROM PUBLIC;

-- Multi-tenant RLS (SPEC-SE-002 contract)
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = current_schema()
                                AND tablename = 'audit_log'
                                AND policyname = 'audit_log_tenant_isolation'
  ) THEN
    CREATE POLICY audit_log_tenant_isolation ON audit_log
      USING (tenant_id::text = current_setting('savia.tenant_id', true));
  END IF;
END $$;

-- Generic trigger function. Captures the row before/after, the user (JWT sub),
-- the agent_id (set per session by the orchestrator), and the tenant_id
-- extracted dynamically from the row's tenant_id column when present.
CREATE OR REPLACE FUNCTION audit_trigger_fn() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_user_id    text := COALESCE(current_setting('request.jwt.claims', true)::jsonb->>'sub', NULL);
  v_agent_id   text := current_setting('savia.agent_id',   true);
  v_session_id text := current_setting('savia.session_id', true);
  v_tenant_id  uuid;
  v_record_id  text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    BEGIN  v_tenant_id := (to_jsonb(OLD)->>'tenant_id')::uuid; EXCEPTION WHEN others THEN v_tenant_id := NULL; END;
    v_record_id := (to_jsonb(OLD)->>'id');
  ELSE
    BEGIN  v_tenant_id := (to_jsonb(NEW)->>'tenant_id')::uuid; EXCEPTION WHEN others THEN v_tenant_id := NULL; END;
    v_record_id := (to_jsonb(NEW)->>'id');
  END IF;

  INSERT INTO audit_log
    (table_name, record_id, operation, old_row, new_row,
     user_id, agent_id, session_id, tenant_id)
  VALUES
    (TG_TABLE_NAME, COALESCE(v_record_id, ''), TG_OP,
     CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
     CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
     v_user_id, v_agent_id, v_session_id, v_tenant_id);

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Helper: attach the audit trigger to any table by regclass
CREATE OR REPLACE PROCEDURE attach_audit(p_table regclass) LANGUAGE plpgsql AS $$
DECLARE
  v_trigger_name text := 'audit_' || replace(p_table::text, '.', '_');
BEGIN
  EXECUTE format(
    'DROP TRIGGER IF EXISTS %I ON %s',
    v_trigger_name, p_table);
  EXECUTE format(
    'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON %s '
    'FOR EACH ROW EXECUTE FUNCTION audit_trigger_fn()',
    v_trigger_name, p_table);
  RAISE NOTICE 'audit trigger attached to %', p_table;
END;
$$;

COMMIT;

-- Usage example:
--   CALL attach_audit('tenants'::regclass);
--   CALL attach_audit('projects'::regclass);
--   CALL attach_audit('billing_invoices'::regclass);
--   CALL attach_audit('agent_sessions'::regclass);
--   CALL attach_audit('api_keys'::regclass);
