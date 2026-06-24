# Agent Credentials — API key → short-lived JWT

> **SPEC**: SPEC-SE-036 (`docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md`)
> **Slice**: 1 (storage + mint primitive). Slices 2 (CLI commands) + 3 (sunset PAT files) follow.
> **Status**: canonical. Replaces file-based PATs as the credential model for autonomous agents.

---

## Tesis (one paragraph)

Los agentes autónomos (`agent/*` branches, overnight-sprint, code-improvement-loop, tech-research-agent) ya **no autentican con Personal Access Tokens de larga duración** contra Azure DevOps / GitHub / MCP servers. En su lugar: la operadora humana genera **API keys hashed**, y cada invocación del agente intercambia su API key por un **JWT efímero** (default 900 s = 15 min) firmado con el secreto del workspace y restringido al **scope mínimo** que la tarea concreta necesita. Si el JWT se filtra: 15 min de exposición y scope mínimo. Si la API key se filtra: revocable en O(1) sin tocar tokens downstream. Esto convierte CLAUDE.md Rule #1 (*"NUNCA hardcodear PAT"*) de **convención** en **infraestructura**: la primitiva criptográfica es la garantía, no el code review.

---

## Diseño

### 1. Storage — `api_keys` (SHA-256 hash + `key_prefix` UX)

Tabla de origen: `docs/propuestas/savia-enterprise/templates/api-keys.sql` (template canónico, MIT clean-room re-implementación de `dreamxist/balance` `20260404000002_api_keys.sql`).

Solo se almacena `sha256(plaintext)` + un `key_prefix` (8 chars visibles para identificación en logs/UI). El plaintext **nunca** se escribe a disco — se imprime una vez en stdout durante creación. Si la usuaria pierde la key, la única vía es revocar y re-emitir.

| Column | Tipo | Por qué |
|---|---|---|
| `id` | uuid | PK |
| `tenant_id` | uuid | RLS multi-tenant (SPEC-SE-002) |
| `key_prefix` | text(8) | UX en logs/list — nunca sensitive solo |
| `key_hash` | text | sha256(plaintext) hex — única `(tenant_id, key_hash)` |
| `scope` | text[] | array de scopes permitidos (`'azure-devops:read'`, `'github:write'`...) |
| `description` | text | comentario humano |
| `created_at` / `last_used_at` / `revoked_at` / `revoked_by` | metadata | auditoría |

### 2. Mint — `api_key_verify()` + `mint_jwt()` (caller-side)

Two SQL helpers (`api_key_verify`, `api_key_scope_is_subset`, `api_key_record_mint`) en el template. La firma JWT propiamente dicha vive en **application code** (`scripts/enterprise/jwt-mint.sh` o equivalente python `jose`/`pyjwt`), no en la base de datos — porque firmar en la DB requeriría `JWT_SIGNING_KEY` en `current_setting`, lo que filtra el secreto a logs.

Flujo:

```
agent invocation
  ↓
api_key_verify($KEY)      → row | NULL
  ↓ (NULL → 401)
api_key_scope_is_subset($scope_subset, row.scope) → bool
  ↓ (false → 403, NEVER upscope — solo downscope)
HS256 sign({tenant_id, agent_id, session_id, scope, iat, exp}, JWT_SIGNING_KEY)
  ↓
api_key_record_mint(row.id, scope_subset, ttl, agent_id, session_id)  ← audit append
  ↓
JWT a stdout (al caller); el caller lo presenta downstream (Azure DevOps, GitHub, MCP)
```

### 3. Mint primitive — `scripts/enterprise/jwt-mint.sh`

CLI bash que implementa el flujo completo. Salidas:

- **JWT en stdout** (caso happy path) — formato `<header_b64url>.<payload_b64url>.<sig_b64url>`
- Códigos de salida documentados:
  - `2` — usage / args inválidos
  - `3` — `SAVIA_ENTERPRISE_DSN` ausente
  - `4` — `JWT_SIGNING_KEY` ausente
  - `5` — `psql` o `openssl` ausentes
  - `6` — fallo de DB en verify
  - `7` — API key inválida / revocada
  - `8` — scope NO es subset (intent de upscoping)

Decisiones de diseño:

- **HS256**, no RS256: el workspace tiene un único firmante (la operadora). RS asymmetric key rotation no aporta vs. complejidad operacional.
- **TTL clamp [60, 3600] s**: 15 min default (AC-04). 1 min mínimo por edge cases tests; 1 h máximo para tareas long-running con cache rotation. Refuse fuera de rango.
- **`--key-stdin`**: la API key NUNCA debe pasar como arg de bash (visible en `ps`). El CLI acepta lectura desde stdin para invocación segura.
- **Audit log non-blocking**: si `api_key_record_mint` falla, el JWT igual se emite pero se imprime `WARNING` a stderr — se priorizó disponibilidad operacional sobre estricta auditoría síncrona; la auditoría puede reconstruirse off-line desde el log de DB.

### 4. Cómo se inyecta la API key al agente

```bash
# La operadora la lanza una vez por sesión:
export SAVIA_AGENT_API_KEY=$(cat ~/.savia/secrets/agent.key)   # mode 600
overnight-sprint --target spec-se-036 --branch agent/spec-se-036-...
```

Dentro del agente (cuando necesita un token):

```bash
JWT=$(jwt-mint.sh --key-stdin --scope github:write <<<"$SAVIA_AGENT_API_KEY")
gh api -H "Authorization: Bearer $JWT" repos/...   # ejemplo conceptual
```

### 5. `JWT_SIGNING_KEY` storage

- **Off-repo**: `~/.savia/secrets/jwt-signing-key`, mode 600.
- **Length**: 32+ bytes (HS256 best practice).
- **Generación**: `openssl rand -base64 32 > ~/.savia/secrets/jwt-signing-key && chmod 600 ~/.savia/secrets/jwt-signing-key`
- **Rotación**: documentada en `docs/rules/domain/savia-enterprise/jwt-key-rotation.md` (Slice 3). Mientras tanto: rotación manual = (1) emit nuevo secret, (2) invalidar todos los JWTs en vuelo dejándolos expirar (max 15 min), (3) reemplazar el archivo, (4) reinvocar agentes activos.

---

## Atribución

Re-implementación clean-room de `dreamxist/balance` `supabase/migrations/20260404000002_api_keys.sql` (MIT). El esquema (sha256 hash + `key_prefix` UX + RLS) replica el patrón fuente. El JWT mint en bash es propio — la fuente original tiene el mint en TS edge function, ortogonal a este workspace.

---

## Cross-refs

- **CLAUDE.md Rule #1** — convención → infraestructura
- **SPEC-SE-002** — RLS multi-tenant para `api_keys` y `api_key_mints`
- **SPEC-SE-037** — `api_key_mints` debería estar wired vía `attach_audit('api_key_mints'::regclass)` en deploy
- **SPEC-SE-004** — agent-framework-interop consume el JWT downstream
- **SPEC-SE-006** — governance-compliance reusa el log de mints como evidencia

---

## CLIs operacionales (Slice 2)

- `scripts/enterprise/api-key-create.sh` — genera key fresca (32 bytes urandom, base64url, prefijo `savia_`), inserta `sha256(key)` + `key_prefix` en `api_keys`, **imprime el plaintext exactamente una vez**. Si la operadora pierde la key: revocar y recrear (no hay recuperación).
- `scripts/enterprise/api-key-list.sh` — inventario filtrable por `--tenant`, `--active`, `--revoked`, `--json`. Nunca muestra `key_hash` ni plaintext (zero-leakage).
- `scripts/enterprise/api-key-revoke.sh` — revoca por `--prefix` (8 chars). 4 safety layers: `--prefix` requerido, no bulk patterns (`all`/`*`/`%`), no wildcards, dry-run por defecto. Llama `CALL api_key_revoke(prefix, actor)`. WARNING explícito: JWTs minteados pre-revoke siguen vivos hasta TTL expiry (≤ 60 min).

## No hace (esta Slice)

- block-pat-file-write.sh implementado (Slice 3 completado, ver seccion 6).
- Sunset de ~/.azure/devops-pat: opt-in tras 1 sprint canary verde (ver seccion 7).
- NO dependencia auth provider externo (no Auth0 / Okta) — JWT firmado localmente.
- NO toca SSO de SPEC-SE-001 foundations (orthogonal).

---

## Slice 3 — Migration + sunset PAT files

### 6. Hook block-pat-file-write.sh (AC-06)

Ubicacion: .opencode/hooks/block-pat-file-write.sh

Intercepta tool Write y Edit que apunte a un path con 'pat' (case-insensitive).
Si el path no esta gitignored: BLOQUEADO con mensaje educativo.
Si esta gitignored (p.ej. ~/.savia/secrets/agent.pat): permitido como fallback durante transicion.

Registro en settings.json:
  event: PreToolUse, matcher: Write|Edit, script: block-pat-file-write.sh

### 7. PAT-shaped string detection en comandos (AC-07)

block-credential-leak.sh extendido con patron SPEC-SE-036: detecta strings 40+ chars
alfanumericos en contexto de autenticacion (=, ": ", "Bearer ", "Authorization: ").
Excluye falsos positivos: hashes git puro (40 hex lowercase), paths filesystem.

### 8. Guia de sunset PAT files (opt-in tras 1 sprint canary verde)

Despues de verificar que el flujo JWT funciona durante 1 sprint completo:

  Paso 1: auditar que scripts leen PAT files
    grep -r 'cat.*pat|\.pat' scripts/ .opencode/hooks/

  Paso 2: reemplazar cada $(cat $PAT_FILE) por el flow JWT:
    export SAVIA_AGENT_API_KEY=$(cat ~/.savia/secrets/agent.key)
    JWT=$(jwt-mint.sh --key-stdin --scope github:write <<<"$SAVIA_AGENT_API_KEY")

  Paso 3: una vez migrado, revocar el token en azure/github y borrar el file:
    rm -f ~/.azure/devops-pat ~/.savia/secrets/*.pat

  Paso 4: marcar en SPEC-SE-036 "Slice 3 sunset completado YYYYMMDD"

Invariante: mientras PAT files existan en disco (aunque gitignored), siguen siendo
validos como fallback. El hook solo bloquea escrituras nuevas a paths no-gitignored.
