---
spec_id: SPEC-141
title: MCP Curated Catalog — catálogo bajo demanda con OAuth, rotación y filtros de seguridad
status: PROPOSED
origin: Investigación 2026-05-23 sobre tendencias workspaces/agentes (output/research-tendencias-workspaces-agentes-2026-20260523.md, sección 3.8, P2). Atlassian deprecate SSE el 2026-06-30 → todos a Streamable HTTP; BlueRock encontró 36.7% MCPs con SSRF y 41% sin auth.
severity: Alta — `mcp.json` está vacío hoy ("bajo demanda") pero sin catálogo curado. Resuelve task #12 pending del backlog.
effort: ~6h (S) — 1 plantilla por proveedor + script de auditoría.
priority: P2 — desbloquea hooks `mcp_tool` (ver SPEC-150) y mata "Claude inventa API antigua" (Context7).
confidence: alta
bucket: Q2 2026
related_specs:
  - SPEC-127 (provider-agnostic env — capa subyacente de detección de hooks)
  - SPEC-143 (SKILL.md conformance — algunas skills se expondrán como MCP servers)
  - SPEC-150 (hooks multi-handler — depende de tener MCP tools disponibles)
---

# SPEC-141 — MCP Curated Catalog

## Why

Hoy `mcp.json` está intencionalmente vacío para arranque rápido (Rule #19, arranque blindado). El diseño es razonable pero se queda corto: no hay catálogo curado de servers con OAuth, rotación y filtros de seguridad, solo una plantilla aislada (`scrapling.json`). Consecuencias:

- Cada vez que un agente necesita docs frescas reinventa el grep (`Context7` resolvería).
- Operaciones repetidas en GitHub van por bash + token plain (el MCP oficial GitHub-go es más seguro).
- No hay un patrón para exponer skills propias (savia-memory, savia-recall, knowledge-graph) como MCP servers consumibles por OpenCode/Cursor/Codex.
- BlueRock (mayo 2026) detectó SSRF en 36.7% y falta de auth en 41% de servers públicos — instalar a ciegas desde awesome-mcp-servers es ahora un riesgo de seguridad medible.

## Scope

### Funcional

> **OpenCode-native**: este spec asume OpenCode v1.14+ como runtime primario. Los MCPs se declaran en `opencode.jsonc` bloque `mcp` con `"type": "local"` (stdio) o `"type": "remote"` (SSE). OAuth se gestiona automáticamente vía Dynamic Client Registration (RFC 7591); tokens persistidos en `~/.local/share/opencode/mcp-auth.json`. Caveat: **Streamable HTTP no nativo todavía** (issue [opencode #8058](https://github.com/anomalyco/opencode/issues/8058)) — para servers Streamable-only, encapsular `mcp-remote --transport http-only` como stdio.

1. **Catálogo `mcp-templates/`**: un fichero `.jsonc.example` por server con:
   - Configuración `type: local` (stdio preferido) o `type: remote` (SSE; Streamable HTTP via mcp-remote stdio wrapper).
   - OAuth automático (`oauth: true` default; `oauth: false` solo para tokens estáticos).
   - Scope mínimo necesario (read-only por defecto).
   - Comentarios sobre tokens efímeros / session-scoped.

2. **Servers iniciales** (filtrados por checklist BlueRock — no SSRF, auth obligatoria, último commit <30 días):
   - `github` (oficial, mantenido por GitHub) — issues, PRs, code search.
   - `context7` — docs vivas por versión, mata invención de APIs antiguas.
   - `linear` — sync con backlog para usuarios Linear.
   - `atlassian` — Jira + Confluence (Streamable HTTP después del 2026-06-30).
   - `sentry` — bug ingestion.
   - `slack` — opcional, para connectors.
   - `cloudflare-workers` — opcional, despliegues.

3. **Exposición de skills propias como MCP stdio servers**:
   - `savia-memory.mcp` — expone memory-store.sh como tool MCP.
   - `savia-recall.mcp` — vector + BM25 + entity-match retrieval.
   - `knowledge-graph.mcp` — query del grafo.
   Esto las hace consumibles desde Cursor/Codex/Antigravity sin reescribir.

4. **Server Cards** (`.well-known/mcp-server-card`) en todos los servers propios para auto-discovery.

5. **Script de auditoría**: `scripts/audit-mcp-templates.sh` — verifica para cada plantilla:
   - Schema válido.
   - Sin secretos hardcoded.
   - Transport != SSE.
   - Scope declarado y mínimo.
   - Si remoto: OAuth declarado.

### No funcional

- Ningún server se arranca al inicio. Catálogo solo se materializa cuando el usuario ejecuta `/mcp-server start <nombre>`.
- Cada plantilla documenta su footprint de tokens/turno.

## Design

### Estructura

```
.opencode/mcp-templates/                # nuevo, primary
├── README.md                            # cómo añadir un server, checklist de seguridad
├── github.jsonc.example
├── context7.jsonc.example
├── linear.jsonc.example
├── atlassian.jsonc.example
├── sentry.jsonc.example
├── slack.jsonc.example
├── cloudflare-workers.jsonc.example
├── savia-memory.jsonc.example          # stdio, expone scripts/memory-store.sh
├── savia-recall.jsonc.example          # stdio
└── knowledge-graph.jsonc.example       # stdio

.claude/mcp-templates/                   # symlink → .opencode/mcp-templates (legacy mirror)

.well-known/
└── mcp-server-card/
    ├── savia-memory.json
    ├── savia-recall.json
    └── knowledge-graph.json

scripts/
└── audit-mcp-templates.sh               # auditoría según OpenCode mcp schema
```

### Patrón de plantilla (ejemplo Context7 en formato OpenCode `mcp` block)

```jsonc
// opencode.jsonc · mcp bloque
{
  "mcp": {
    "context7": {
      "type": "local",
      "command": ["npx", "-y", "@upstash/context7-mcp"],
      "environment": {
        "CONTEXT7_API_KEY": "${env:CONTEXT7_API_KEY}"
      },
      // metadata Savia (no parte del schema OpenCode, sirve para audit)
      "_savia_meta": {
        "scope": "read:docs",
        "auth": "api_key",
        "rotation_days": 90,
        "trigger": "antes de invocar API cuya versión no conoces con seguridad",
        "token_budget": "low — solo system prompt context"
      }
    }
  }
}
```

Para servers remotos OAuth (ej. Linear):

```jsonc
{
  "mcp": {
    "linear": {
      "type": "remote",
      "url": "https://mcp.linear.app/sse",
      "oauth": true,
      "_savia_meta": { "scope": "read:issues", "rotation_days": 30 }
    }
  }
}
```

## Acceptance Criteria

- [ ] AC-01: `.opencode/mcp-templates/` contiene 7 plantillas mínimas (formato OpenCode `mcp` block) con README explicando uso.
- [ ] AC-02: `audit-mcp-templates.sh` pasa sobre las 7 plantillas (schema válido contra `https://opencode.ai/config.json`, no secretos hardcoded, type ∈ {local, remote}).
- [ ] AC-03: 3 skills propias (savia-memory, savia-recall, knowledge-graph) exponibles como MCP stdio — smoke test con `opencode mcp list` muestra los servers; `opencode run --no-interactive` puede invocar sus tools.
- [ ] AC-04: Server Cards en `.well-known/mcp-server-card/` validan contra spec MCP Registry oficial.
- [ ] AC-05: Documentación en `docs/rules/domain/mcp-catalog-policy.md` explicando checklist BlueRock (no SSRF, auth, commit recency) + nota sobre HTTP Streamable workaround (`mcp-remote` stdio wrapper).
- [ ] AC-06: BATS test `tests/test-mcp-catalog.bats` verifica integridad de las plantillas.
- [ ] AC-07: Workflow `opencode mcp auth <server>` documentado para OAuth manual cuando DCR no aplica.

## Agent Assignment

- **Capa**: Infrastructure
- **Agente principal**: `security-guardian` (auditoría de plantillas)
- **Agente secundario**: `dev-orchestrator` (creación de stdio wrappers para skills propias)
- **Skills involucradas**: `azure-devops-queries` (si Atlassian/Linear sustituyen consulta directa), `savia-memory`, `web-research` (para validar últimas versiones de servers)

## Slicing

- **Slice 1** (2h) — Crear estructura `mcp-templates/` + plantillas para `github` y `context7` + audit script básico.
- **Slice 2** (2h) — Exponer `savia-memory` como stdio MCP server (sin Server Card todavía).
- **Slice 3** (1h) — Resto de plantillas (linear, atlassian, sentry, slack, cloudflare-workers).
- **Slice 4** (1h) — Server Cards + smoke tests + docs.

## Feasibility Probe

Slice 1 actúa como probe: si Context7 stdio se integra sin OAuth complicado y reduce >30% el "no sé qué versión usar" en 5 invocaciones reales → continue. Si no, documentar y degradar a "vigilar".

## Riesgos

- **Lock-in al ecosistema MCP**: mitigación — todos los servers propios son stdio (no necesitan red), seguimos siendo sovereign.
- **Token leakage en plantillas**: gatekeeping vía `audit-mcp-templates.sh` corriendo en pre-commit hook.
- **Drift de upstream**: Atlassian deprecate SSE 2026-06-30 — la plantilla debe usar Streamable HTTP de entrada. Vigilancia via SPEC-146 (watcher mensual).
