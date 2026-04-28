---
status: PROPOSED
---

# SPEC-SE-036: API-Key → Short-Lived JWT Mint for Agent CLIs

> **Estado**: Draft — Roadmap Era 232
> **Prioridad**: P1 (Sovereignty + security hardening)
> **Dependencias**: SPEC-SE-004 (agent-framework-interop), SPEC-SE-002 (multi-tenant RLS), Rule #1 CLAUDE.md
> **Era**: 232
> **Inspiración**: `dreamxist/balance` `supabase/migrations/20260404000002_api_keys.sql` —
> SHA-256 hashed keys + `key_prefix` for UX + RLS isolation per user; README confirma
> short-lived JWTs minted from API keys, never service_role.

---

## Problema

Hoy los agentes autónomos (`agent/*` branches, overnight-sprint, code-improvement-loop,
tech-research-agent) autentican contra Azure DevOps / GitHub / MCP servers vía
**Personal Access Tokens** de larga duración:

- File-based: `$HOME/.azure/devops-pat`
- Vida útil: ≥6 meses por defecto, a menudo 1 año
- Permisos: full scope (porque rotar uno scoped es fricción)
- Rotación: manual, recordada por la usuaria

CLAUDE.md Rule #1 (`NUNCA hardcodear PAT — siempre $(cat $PAT_FILE)`) es enforced
**por convención**, no por infraestructura. Si un agente lo desobedece, sólo
lo coge un code-review humano.

Riesgo concreto: un agente con PAT robado tiene `merge` + `branch -D` + `push --force`
durante meses. Auditoría posterior tiene que reconstruir qué hizo cuándo desde
el log de Azure DevOps, sin trazabilidad cryptográfica.

**Cost of inaction**: cuando Anthropic restrinja Claude Code (Pro→Max ya en abril
2026, API-only previsto en 6-18 meses, contexto SE-077) y aumente el número de
agentes autónomos cross-frontend (OpenCode, Codex, Cursor), el modelo file-based
PAT escala mal. Cada nuevo frontend = nuevo file = nuevo punto de fuga.

## Tesis

Sustituir el modelo "PAT file-based de larga duración" por **API key hashed +
JWT efímero per agent invocation**:

1. La usuaria (humano) genera API keys via comando local. La key se muestra UNA
   vez en stdout; el sistema sólo guarda `sha256(key)` + un `key_prefix` (8 chars
   visibles para UX en logs/dashboards).
2. Cada vez que un agente se invoca, intercambia su API key por un JWT efímero
   (15 min default) firmado con la key del workspace. El JWT lleva: `tenant_id`,
   `agent_id`, `scope_minimised` (computed per-task), `exp`.
3. Los downstream callers (Azure DevOps, GitHub, MCP) reciben el JWT, no la API key.
4. Si el JWT se filtra: 15 min de exposición, scope mínimo. Si la API key se
   filtra: revocable en O(1) sin tocar downstream tokens.
5. Auditoría: cada mint se registra en `api_key_mints` con timestamp + scope +
   agent_id. Trazabilidad cryptográfica vs. log forensics.

## Scope (3 slices)

### Slice 1 (S, 4h) — Storage + minting primitive

Tabla:

```sql
CREATE TABLE api_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  key_prefix text NOT NULL,        -- first 8 chars, visible
  key_hash text NOT NULL,          -- sha256(full_key), unique
  scope text[] NOT NULL,           -- ['azure-devops:read', 'github:write', ...]
  description text,
  created_at timestamptz DEFAULT now(),
  last_used_at timestamptz,
  revoked_at timestamptz,
  UNIQUE (tenant_id, key_hash)
);

CREATE INDEX api_keys_active ON api_keys (tenant_id) WHERE revoked_at IS NULL;
```

Función `mint_jwt(p_api_key text, p_scope_subset text[]) RETURNS text`:
- Verifica `sha256(p_api_key)` existe + no revocada
- `scope_subset ⊆ stored_scope` (downscoping permitido, never upscoping)
- Firma JWT con `JWT_SIGNING_KEY` del workspace (env var)
- TTL configurable, default 900s (15 min)
- Registra mint en `api_key_mints` (audit log)

### Slice 2 (M, 6h) — CLI + agent integration

CLI commands:
- `bash scripts/enterprise/api-key-create.sh --scope <s1,s2,...> --desc "..."` →
  imprime la key una vez, registra hash + prefix
- `bash scripts/enterprise/api-key-list.sh` → muestra prefix, scope, last_used
- `bash scripts/enterprise/api-key-revoke.sh <prefix>` → marca revoked_at
- `bash scripts/enterprise/jwt-mint.sh --key <api_key> --scope <subset>` → JWT a stdout

Wrapper de invocación: cualquier `agent/*` branch script que necesite token
llama internamente a `jwt-mint.sh`, jamás lee un PAT file. La API key vive en
una variable de entorno `SAVIA_AGENT_API_KEY` que el operador inyecta al lanzar
overnight-sprint, code-improvement-loop, etc.

### Slice 3 (M, 4h) — Migration + sunset PAT files

- Doc migration guide en `docs/rules/domain/savia-enterprise/agent-jwt-mint.md`
- Hook `block-pat-file-write.sh` (PreToolUse, matcher `Write`) bloquea
  intentos de escribir a `*pat*` paths fuera de gitignore
- pre-commit gate detecta PAT-shaped strings (40+ char hex/base64) en diff
  (existing `block-credential-leak.sh` extiende su patrón)
- Después de 1 sprint con uso real verificado: borrar `$HOME/.azure/devops-pat`
  (manual, doc paso a paso)

## Acceptance criteria

- [ ] AC-01 Tabla `api_keys` con SHA-256 hash + key_prefix UI
- [ ] AC-02 Función `mint_jwt()` con scope downscoping enforce
- [ ] AC-03 4 CLI commands (create, list, revoke, mint)
- [ ] AC-04 JWT efímero ≤900s, scope mínimo signed
- [ ] AC-05 Audit trail `api_key_mints` append-only (sinergia SPEC-SE-037)
- [ ] AC-06 Hook `block-pat-file-write.sh` bloquea escrituras a paths PAT
- [ ] AC-07 `block-credential-leak.sh` detecta PAT-shaped strings en diff
- [ ] AC-08 Tests BATS ≥12 score ≥80 + pgTAP ≥6 (función mint)
- [ ] AC-09 Doc `docs/rules/domain/savia-enterprise/agent-jwt-mint.md`
- [ ] AC-10 SQL template `docs/propuestas/savia-enterprise/templates/api-keys.sql`
- [ ] AC-11 CHANGELOG entry

## No hace

- NO sustituye `pm-config.local.md` AUTONOMOUS_REVIEWER (otra capa)
- NO promete zero-PAT inmediato — Slice 3 sunset es opt-in tras 1 sprint
- NO añade dependencia auth provider externo (no Auth0, no Okta) — JWT firmado localmente
- NO toca SSO de SPEC-SE-001 foundations (orthogonal)
- NO requiere Supabase ni servicio managed: Postgres + librería JWT (jose, pyjwt) bastan

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| `JWT_SIGNING_KEY` filtrado → forge tokens | Baja | Alto | Storage off-repo (`~/.savia/secrets/`); rotación documentada |
| Drift entre scope declarado y consumed downstream | Media | Medio | Cada downstream registra qué scope recibió; reconcile via SPEC-SE-035 |
| Performance: mint en cada call satura DB | Media | Medio | Cache JWT in-memory por agent worker mientras `now() < exp - 60s` |
| Migración rompe automatización existente | Alta | Bajo | Slice 3 sunset opt-in tras 1 sprint canary verde; PAT files tolerados durante transición |

## Dependencias

- **Bloquea**: nada
- **Habilita**: SPEC-SE-006 (governance-compliance — auditoría granular por mint)
- **Sinergia**: SPEC-SE-037 (audit-trigger — `api_key_mints` table audited automáticamente)
- **Sinergia**: SE-077 OpenCode replatform — agentes en cualquier frontend usan el mismo flow
- **CLAUDE.md Rule #1**: pasa de "convención" a "infraestructura"

## Referencias

- `dreamxist/balance` `supabase/migrations/20260404000002_api_keys.sql` (origen del hash + prefix pattern)
- SPEC-SE-004 agent-framework-interop (consumer)
- SPEC-SE-002 multi-tenant RLS (foundation)
- CLAUDE.md Rule #1
- License compatibility: Balance MIT — JWT mint code en TS allá, re-implement en bash/Postgres aquí
- Caveat: el JWT-mint code real de Balance vive en CLI/edge-function TS — esta spec
  trata el JWT-mint half **como pattern a diseñar**, no como pattern a copiar verbatim.
