# MCP Catalog Policy — SPEC-141

> **Rule** — Antes de activar un MCP server público de terceros, pasar el
> checklist BlueRock. Los servers propios (savia-*) están exentos del
> checklist remoto pero deben tener Server Card en `.well-known/`.

## Por qué este checklist

BlueRock (mayo 2026) detectó SSRF en 36.7% y falta de auth en 41% de
servers MCP públicos. Instalar a ciegas desde `awesome-mcp-servers` es
un riesgo medible. La política mínima:

## Checklist BlueRock (obligatorio para terceros)

1. **No SSRF** — el server NO recibe URLs arbitrarias del LLM sin sandboxing.
2. **Auth obligatoria** — API key, OAuth o token. NUNCA `oauth: false` sin
   token estático documentado.
3. **Commit recency** — último commit upstream <30 días.
4. **Scope mínimo** — declarado en `_savia_meta.scope`, read-only por defecto.
5. **Audit OK** — `bash scripts/audit-mcp-templates.sh` pasa.

## Rotación

- API keys: `_savia_meta.rotation_days` ≤ 90.
- OAuth tokens: 30 días recomendado.
- Tokens efímeros (session-scoped) cuando el server lo soporta.

## Streamable HTTP workaround

OpenCode v1.14 no soporta HTTP Streamable nativo
(issue [#8058](https://github.com/anomalyco/opencode/issues/8058)).
Para servers Streamable-only (ej. Atlassian post 2026-06-30) usar el
wrapper `mcp-remote --transport http-only` como stdio.

## Catálogo curado actual (SPEC-141 Slice 1+2)

| Server | Tipo | Checklist BlueRock |
|---|---|---|
| github | local stdio | passed 2026-05-23 |
| context7 | local stdio | passed 2026-05-23 |
| linear | remote sse | passed 2026-05-23 |
| atlassian | local stdio (wrapper) | passed 2026-05-23 |
| sentry | remote sse | passed 2026-05-23 |
| slack | remote sse | passed 2026-05-23 |
| cloudflare-workers | remote sse | passed 2026-05-23 |
| savia-memory | local stdio (own) | n/a (no red) |
| savia-recall | local stdio (own, futuro) | n/a (no red) |
| knowledge-graph | local stdio (own) | n/a (no red) |

## Anti-patterns

- ❌ Activar un server con `autoApprove` global.
- ❌ Activar un server público sin pasar el audit script.
- ❌ Persistir tokens en el repo. Usar `${env:VAR}` o `opencode mcp auth`.
- ❌ Concede scope `write` por defecto. Empezar read-only.

## Auditoría continua

SPEC-146 (ecosystem-watcher) vigila `modelcontextprotocol/servers` y emite
señal cuando hay nuevas plantillas para evaluar.
