---
context_tier: L3
spec: SE-003
status: IMPLEMENTED
---

# Enterprise MCP Protocol — Catálogo y consumo de MCP servers Savia

> Ref: `docs/propuestas/savia-enterprise/SPEC-SE-003-mcp-catalog.md`

## Catálogo de MCP servers (7 servers)

| ID | Lang | Capacidades | Estado |
|----|------|-------------|--------|
| `savia-pm-mcp` | .NET | PBIs, sprints, capacity, velocity | stub |
| `savia-azdevops-mcp` | .NET | WIQL, work items, pipelines, repos | stub |
| `savia-memory-mcp` | TypeScript | recall, save, graph, domains | available |
| `savia-shield-mcp` | Python | clasificación N1-N4, masking, PII | stub |
| `savia-sdd-mcp` | .NET | spec validation, slicing | stub |
| `savia-governance-mcp` | TypeScript | audit, compliance, bias check | stub |
| `savia-legal-mcp` | Python | legalize-es, RGPD, compliance ES | stub |

El catálogo completo está en `output/mcp-catalog/catalog.json` (generado por
`scripts/enterprise/mcp-catalog-generate.sh`).

## Cómo consumir un MCP server Savia

### En Claude Desktop

```json
{
  "mcpServers": {
    "savia-memory-mcp": {
      "command": "node",
      "args": ["/path/to/savia-memory-mcp/dist/index.js"]
    }
  }
}
```

### En código (TypeScript SDK)

```typescript
import { MCPClient } from "@modelcontextprotocol/sdk";

const client = new MCPClient({
  transport: { type: "stdio", command: "node", args: ["dist/index.js"] }
});

await client.connect();
const result = await client.callTool("memory_recall", { query: "sprint velocity" });
```

### En Microsoft Agent Framework

```yaml
# agent-definition.yaml
tools:
  - type: mcp
    server: savia-memory-mcp
    transport: http
    url: http://localhost:3001
```

## Cómo publicar un MCP server nuevo

1. Genera el scaffold:
   ```bash
   bash scripts/enterprise/mcp-server-stub.sh \
     --server-id savia-{name}-mcp \
     --output-dir .claude/enterprise/mcp/
   ```

2. Implementa la lógica en `src/index.ts` (TypeScript) o el lenguaje del catálogo.

3. Añade la entrada al catálogo en `output/mcp-catalog/catalog.json`:
   ```json
   {
     "id": "savia-{name}-mcp",
     "lang": "TypeScript",
     "capabilities": ["..."],
     "tools": [...],
     "status": "available"
   }
   ```

4. Regenera el catálogo:
   ```bash
   bash scripts/enterprise/mcp-catalog-generate.sh
   ```

5. Publica en el registry MCP (Anthropic) siguiendo las instrucciones de
   `https://modelcontextprotocol.io/registry`.

## Protocolo MCP v1

Cada server implementa:

| Método | Descripción |
|--------|-------------|
| `tools/list` | Lista las tools disponibles con sus schemas |
| `tools/call` | Invoca una tool con los argumentos |
| `resources/list` | (opcional) Lista recursos accesibles |
| `prompts/list` | (opcional) Lista prompts preconstruidos |

### Seguridad

- **Autenticación**: JWT de Savia (SPEC-SE-036) o API key per-tenant.
- **Transporte**: stdio (local) o HTTP con TLS (red).
- **PII**: el server NUNCA expone contenido N4 — solo hashes.
- **Scope downscoping**: `jwt-mint.sh` garantiza que el JWT tiene solo los scopes necesarios.

## Runtimes compatibles verificados

| Runtime | Estado |
|---------|--------|
| Claude Desktop | verificado |
| Claude Code (cli) | verificado |
| Microsoft Agent Framework 1.0 | stub |
| LangGraph | stub |
| OpenAI Assistants API | stub |
| Codex CLI | pendiente |

## Regenerar el catálogo

```bash
bash scripts/enterprise/mcp-catalog-generate.sh
# → output/mcp-catalog/catalog.json
```

## Dependencias

- SE-001: layer contract (extracción sin romper Core)
- SE-007: SSO/autenticación federada para servidores remotos
- SE-036: JWT mint para autenticación corta duración
