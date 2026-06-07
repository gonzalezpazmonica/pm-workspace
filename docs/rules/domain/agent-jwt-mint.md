---
context_tier: L2
token_budget: 700
feature_flag: SAVIA_JWT_MINT_ENABLED
default: false
ref: docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md
---

# agent-jwt-mint — API Key → Short-Lived JWT para Agentes

> Feature flag: `SAVIA_JWT_MINT_ENABLED` (default `false`).
> Activar tras 1 sprint canary verde. Hasta entonces, PAT files tolerados.

## Qué es

Sustituye los PAT de larga duración por **JWTs efímeros de 15 min** firmados
localmente. Cada invocación de agente intercambia su API key por un JWT con
scope mínimo. Si el JWT se filtra: 15 min de exposición, sin acceso a la key.
Si la API key se filtra: revocable en O(1).

Storage: `${PROJECT_ROOT:-.}/.savia/api-keys.db` (SQLite, gitignored).

## Crear un API key

```bash
bash scripts/jwt-mint.sh init          # crea schema (una sola vez)
bash scripts/jwt-mint.sh create \
  --name "overnight-sprint-agent" \
  --scope "azure-devops:read"
# stdout → key_prefix: abc12345
#           key: abc12345<56 hex chars más>   ← guardar en ~/.savia/secrets/, NUNCA en repo
```

La key completa se muestra **una sola vez** en stdout. El sistema guarda
únicamente `sha256(key)` + `key_prefix` (primeros 8 chars).

## Mintear un JWT efímero

```bash
# TTL default: 900s (15 min)
JWT=$(bash scripts/jwt-mint.sh mint abc12345)

# TTL custom + scope reducido
JWT=$(bash scripts/jwt-mint.sh mint abc12345 --ttl 300 --scope "azure-devops:read")

# Usar el JWT en downstream calls
curl -H "Authorization: Bearer $JWT" https://dev.azure.com/...
```

## Listar y revocar keys

```bash
bash scripts/jwt-mint.sh list              # tabla: key_prefix, name, scope, status
bash scripts/jwt-mint.sh revoke abc12345   # marca como revoked
```

## Protección de escritura a paths PAT

El hook `block-pat-file-write.sh` bloquea intentos de escribir a paths que
coincidan con patrones PAT (`*/.pat_file`, `*_PAT`, `ANTHROPIC_API_KEY*`, etc.):

```bash
OPENCODE_TOOL_INPUT_PATH="$HOME/.azure/devops-pat" bash scripts/block-pat-file-write.sh
# → exit 2 con mensaje BLOCK

bash scripts/block-pat-file-write.sh --check-only --path "$HOME/.azure/devops-pat"
# → exit 0 con WARN en stderr (modo auditoría, no bloquea)
```

## Sunset PAT files (opt-in, post 1 sprint canary)

1. `SAVIA_JWT_MINT_ENABLED=true` en `.claude/rules/pm-config.local.md`.
2. Todos los agentes usan `SAVIA_AGENT_API_KEY`, no `$(cat $PAT_FILE)`.
3. Eliminar `$HOME/.azure/devops-pat` y equivalentes (manual).
4. Actualizar `autonomous-safety.md` para referenciar el nuevo flow.

**NO eliminar PAT files antes de 1 sprint sin errores de autenticación.**
## Audit trail
Cada mint → `api_key_mints`: `mint_id | key_prefix | scope | ttl | minted_at | expires_at`.
Sinergia: SPEC-SE-037 captura estos eventos automáticamente.
