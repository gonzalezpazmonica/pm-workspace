# Agent Credentials — API key → short-lived JWT

> **SPEC**: SPEC-SE-036 (`docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md`)
> **Slices implementados**: 1 (storage + mint primitive), 2 (CLI commands), 3 (migration + sunset PAT files)
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

## Migración PAT → JWT (Slice 3)

> **Fundamento**: CLAUDE.md Rule #1 — `NUNCA hardcodear PAT — siempre $(cat $PAT_FILE)`.
> Este proceso convierte esa convención en infraestructura: el hook y el pre-commit gate
> bloquean la creación de nuevos PAT files, y los agentes deben usar JWT efímeros.

### Verificar estado actual

Detecta PAT files existentes en rutas conocidas:

```bash
# Rutas canónicas de credencial files en este workspace
find ~/.azure ~/.savia ~/.config/savia \
  -name "*devops*" -o -name "*github-pat*" 2>/dev/null

# Verifica que el hook está activo
bash .opencode/hooks/block-pat-file-write.sh --path /tmp/test-devops-pat 2>&1

# Master switch actual (default: on)
echo "SAVIA_PAT_BLOCK=${SAVIA_PAT_BLOCK:-on}"
```

### Proceso de migración

**Paso 1 — Genera JWT_SIGNING_KEY** (si no existe):

```bash
mkdir -p ~/.savia/secrets && chmod 700 ~/.savia/secrets
# Genera clave de 32 bytes y guárdala off-repo, mode 600
openssl rand -base64 32 > ~/.savia/secrets/jwt-signing-key
chmod 600 ~/.savia/secrets/jwt-signing-key
export JWT_SIGNING_KEY=$(cat ~/.savia/secrets/jwt-signing-key)
```

**Paso 2 — Crea una API key con el scope mínimo necesario**:

```bash
# Scope recomendado para agent autonomy standard
bash scripts/enterprise/api-key-create.sh \
  --scope "azure-devops:read,github:write" \
  --desc "overnight-sprint canary key $(date +%Y%m%d)"
# Nota: el plaintext se muestra UNA vez — guárdalo en el vault local
```

**Paso 3 — Guarda la API key fuera del repo**:

```bash
# El plaintext impreso en el paso anterior (savia_XXXXXXXX...) va al vault:
echo "savia_<plaintext_from_step2>" > ~/.savia/secrets/agent.key
chmod 600 ~/.savia/secrets/agent.key
# NUNCA commitear este fichero — está en .gitignore
```

**Paso 4 — Prueba que el JWT mint funciona**:

```bash
export SAVIA_AGENT_API_KEY=$(cat ~/.savia/secrets/agent.key)
JWT=$(bash scripts/jwt-mint.sh --key-stdin --scope "azure-devops:read" \
      <<<"$SAVIA_AGENT_API_KEY")
# Verifica que el JWT tiene el formato correcto (3 partes base64url separadas por .)
echo "$JWT" | awk -F. '{print NF" partes — OK si ==3"}'
```

**Paso 5 — Actualiza los scripts de invocación de agentes**:

```bash
# Modelo anterior (file-based):
# Reemplaza:  export AZURE_DEVOPS_PAT=$(cat ~/.azure/devops-pat)
# Con:        export SAVIA_AGENT_API_KEY=$(cat ~/.savia/secrets/agent.key)
#
# El agente llama internamente a scripts/jwt-mint.sh cuando necesita un token.
# Ver agent-jwt-mint.md §3 para el flujo completo.
```

### Después de 1 sprint

Con 1 sprint de uso real verificado (agentes funcionando con JWT, sin regresiones),
borra el archivo de credencial de larga duración de forma segura:

```bash
# 1. Verifica que ningún script activo lo referencia:
grep -r "devops-pat\|azure-pat\|github-pat" scripts/ .claude/ .opencode/ 2>/dev/null \
  | grep -v "\.bats\|test-\|#\|block-pat"

# 2. Revoca la credencial en el proveedor ANTES de borrar el archivo local:
#    Azure DevOps: dev.azure.com > User Settings > Personal access tokens > Revoke
#    GitHub:       github.com > Settings > Developer settings > Tokens > Delete

# 3. Borra el archivo local con shred (sobrescribe antes de eliminar):
shred -u ~/.azure/devops-pat 2>/dev/null || rm -f ~/.azure/devops-pat
echo "credential file eliminated: $(date)" >> ~/.savia/migration-log.txt

# 4. Confirma que el hook bloquea recreación:
SAVIA_PAT_BLOCK=on bash .opencode/hooks/block-pat-file-write.sh \
  --path /tmp/devops-pat 2>&1  # debe imprimir BLOCK
```

### Rollback

Si algo falla durante la migración y necesitas volver al modelo anterior:

```bash
# 1. Desactiva temporalmente el hook de bloqueo:
export SAVIA_PAT_BLOCK=off

# 2. Regenera la credencial en el proveedor y restaura el archivo local:
#    (seguir instrucciones del proveedor para generar nueva credencial)
#    Guarda el valor en ~/.azure/devops-pat, chmod 600

# 3. Restaura los scripts de invocación al modelo anterior:
#    Reemplaza: export SAVIA_AGENT_API_KEY=...
#    Con:       export AZURE_DEVOPS_PAT=$(cat ~/.azure/devops-pat)

# 4. Documenta el rollback:
echo "$(date): rollback — motivo: <describe aquí>" >> ~/.savia/migration-log.txt

# IMPORTANTE: SAVIA_PAT_BLOCK=off es temporal.
# Reactivar con SAVIA_PAT_BLOCK=on en cuanto el bloqueante esté resuelto.
# Abrir issue para resolver el bloqueante antes del siguiente intento.
```

### Infraestructura de bloqueo activa (Slice 3)

| Componente | Ubicación | Qué hace |
|---|---|---|
| Hook `block-pat-file-write.sh` | `.opencode/hooks/` | PreToolUse Write/Edit — bloquea writes a paths con `pat`/`token`/`secret` fuera de .gitignore |
| Patrón PAT-shaped en `block-credential-leak.sh` | `.opencode/hooks/` | Detecta strings 40+ chars hex/base64 en comandos bash |
| Master switch | `SAVIA_PAT_BLOCK=on\|off` | `on` por defecto — es seguridad, no opt-in |

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

## No hace

- NO sustituye `pm-config.local.md` AUTONOMOUS_REVIEWER (otra capa).
- NO promete zero-PAT inmediato — Slice 3 sunset es opt-in tras 1 sprint canary verde.
- NO añade dependencia auth provider externo (Auth0 / Okta) — JWT firmado localmente.
- NO toca SSO de SPEC-SE-001 foundations (orthogonal).
