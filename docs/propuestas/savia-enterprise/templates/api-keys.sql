-- api-keys.sql — Reference template for SPEC-SE-036
--
-- Hashed API keys + short-lived JWT mint per agent invocation. Replaces
-- file-based PATs of arbitrary lifetime (Rule #1 enforcement at infrastructure
-- level, not convention level).
--
-- Reference: dreamxist/balance supabase/migrations/20260404000002_api_keys.sql (MIT)
-- Re-implementación. JWT minting code en bash/python lives in
-- scripts/enterprise/jwt-mint.sh — this file is the storage + verification half.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS api_keys (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL,                -- REFERENCES tenants(id) when present
  key_prefix    text NOT NULL,                -- first 8 chars, visible in logs/UI
  key_hash      text NOT NULL,                -- sha256 of the full plaintext
  scope         text[] NOT NULL DEFAULT '{}', -- e.g. ['azure-devops:read', 'github:write']
  description   text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  last_used_at  timestamptz,
  revoked_at    timestamptz,
  revoked_by    text,
  UNIQUE (tenant_id, key_hash)
);

CREATE INDEX IF NOT EXISTS api_keys_active
  ON api_keys (tenant_id) WHERE revoked_at IS NULL;

-- Mint audit: append-only log of every JWT issued from an API key.
-- This table SHOULD be wired through SPEC-SE-037 (attach_audit) too.
CREATE TABLE IF NOT EXISTS api_key_mints (
  id          bigserial PRIMARY KEY,
  api_key_id  uuid NOT NULL REFERENCES api_keys(id),
  scope       text[] NOT NULL,                -- subset that was actually minted
  ttl_seconds int NOT NULL,
  agent_id    text,                           -- savia.agent_id
  session_id  text,
  minted_at   timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL
);

CREATE INDEX IF NOT EXISTS api_key_mints_recent
  ON api_key_mints (api_key_id, minted_at DESC);

-- Verify a presented key. Returns NULL if invalid/revoked, the key row otherwise.
-- The CALLER then validates scope_subset ⊆ row.scope before signing the JWT.
CREATE OR REPLACE FUNCTION api_key_verify(p_plaintext text)
RETURNS api_keys
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_hash text := encode(digest(p_plaintext, 'sha256'), 'hex');
  v_row  api_keys%ROWTYPE;
BEGIN
  SELECT * INTO v_row FROM api_keys
    WHERE key_hash = v_hash AND revoked_at IS NULL
    LIMIT 1;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  RETURN v_row;
END;
$$;

-- Helper: scope_subset ⊆ scope_full (every element in subset must be in full)
CREATE OR REPLACE FUNCTION api_key_scope_is_subset(
  scope_subset text[],
  scope_full   text[]
) RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
  SELECT scope_subset <@ scope_full;
$$;

-- Record a mint after the JWT has been signed in application code.
-- Returns the mint id for logging.
CREATE OR REPLACE FUNCTION api_key_record_mint(
  p_api_key_id uuid,
  p_scope text[],
  p_ttl_seconds int,
  p_agent_id text,
  p_session_id text
) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
  v_id bigint;
BEGIN
  INSERT INTO api_key_mints
    (api_key_id, scope, ttl_seconds, agent_id, session_id, expires_at)
  VALUES
    (p_api_key_id, p_scope, p_ttl_seconds, p_agent_id, p_session_id,
     now() + (p_ttl_seconds || ' seconds')::interval)
  RETURNING id INTO v_id;

  -- Update last_used_at for visibility
  UPDATE api_keys SET last_used_at = now() WHERE id = p_api_key_id;
  RETURN v_id;
END;
$$;

-- Revocation
CREATE OR REPLACE PROCEDURE api_key_revoke(p_prefix text, p_actor text) LANGUAGE plpgsql AS $$
BEGIN
  UPDATE api_keys
     SET revoked_at = now(), revoked_by = p_actor
   WHERE key_prefix = p_prefix AND revoked_at IS NULL;
  IF NOT FOUND THEN
    RAISE NOTICE 'no active key with prefix %', p_prefix;
  END IF;
END;
$$;

COMMIT;

-- Example usage (application side, NOT executed by this template):
--   key_plaintext = 'savia_<random_32>'
--   key_prefix    = first 8 chars
--   key_hash      = sha256(plaintext) hex
--   INSERT INTO api_keys (tenant_id, key_prefix, key_hash, scope, description) VALUES (...);
--
-- On each agent invocation:
--   row = api_key_verify($KEY)
--   if row is null → 401
--   if not api_key_scope_is_subset($scope_subset, row.scope) → 403
--   jwt = jose.sign({tenant_id: row.tenant_id, scope: $scope_subset, exp: now+900}, JWT_SIGNING_KEY)
--   api_key_record_mint(row.id, $scope_subset, 900, $agent_id, $session_id)
--   return jwt
