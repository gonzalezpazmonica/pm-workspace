# SPEC-SE-003 — MCP Server Catalog

> **Prioridad:** P0 · **Estima:** 8 días · **Tipo:** interoperabilidad + distribución

## Objetivo

Publicar un catálogo de **MCP servers agnósticos** que permitan a cualquier
runtime compatible con Model Context Protocol (Claude, Codex, Copilot,
Agent Framework, Gemini) consumir capacidades de Savia sin depender de Savia
como runtime. Savia se convierte en **proveedor de capacidades**, no en
plataforma cautiva.

## Principios afectados

- #2 Independencia del proveedor (MCP es estándar multi-vendor)
- #1 Soberanía (el cliente elige el runtime)
- #3 Honestidad radical (capacidades medibles y auditables)

## Diseño

### Catálogo inicial (7 MCP servers)

| MCP Server | Lenguaje | Capacidades | Valor comercial |
|-----------|----------|-------------|-----------------|
| `savia-pm-mcp` | .NET | PBIs, sprints, capacity, velocity | Azure DevOps + Jira + Savia Flow |
| `savia-azdevops-mcp` | .NET | WIQL, work items, pipelines, repos | Hueco en ecosistema .NET |
| `savia-memory-mcp` | TypeScript | Recall, save, graph, domains | Memoria soberana multi-runtime |
| `savia-shield-mcp` | Python | Clasificación N1-N4, masking | Compliance AI Act |
| `savia-sdd-mcp` | .NET | Spec validation, slicing | Spec-Driven Development estándar |
| `savia-governance-mcp` | TypeScript | Audit, compliance, bias check | AI governance |
| `savia-legal-mcp` | Python | legalize-es queries | Compliance legal España |

### Contratos MCP

Cada server:
- Implementa MCP spec v1 (tools, resources, prompts)
- Tiene su propio repo con licencia MIT
- Publica en registry oficial MCP de Anthropic
- Binario o container distribuible sin Savia instalado
- Se testea contra Claude Desktop, MS Agent Framework, Codex

### Estructura del repo por MCP

```
savia-{name}-mcp/
├── README.md              ← inglés, con 3 demos
├── LICENSE                ← MIT
├── src/                   ← implementación
├── tests/                 ← golden set contra runtime real
├── docs/                  ← endpoints, tools, resources
└── .github/workflows/     ← CI multiplataforma
```

### Integración con Savia Core

Los MCP servers SON código extraído de Savia (no duplicado). Savia Core
invoca las mismas funciones internamente. El MCP server es una capa de
adapter que las expone vía stdio/HTTP.

## Criterios de aceptación

1. 7 repos creados en `github.com/{org}/savia-*-mcp`
2. `savia-pm-mcp` funcional contra Azure DevOps real con tests end-to-end
3. `savia-azdevops-mcp` publicado en MCP registry
4. Demo vídeo 3 min: Claude Desktop invocando `/sprint-status` vía MCP
5. Cada MCP testea contra ≥2 runtimes distintos
6. Documentación en inglés con ejemplos reproducibles
7. Anuncio público con 1 post técnico por MCP

## Out of scope

- MCP clients (Savia Core ya tiene)
- Autenticación federada (SE-007)

## Dependencias

- SE-001 (layer contract para extraer sin romper Core)
- SE-008 (estrategia de licencia y distribución)

## Impacto estratégico

Esta spec ejecuta directamente la apuesta 5.6 del informe estratégico:
*"Construir un MCP server público en .NET con valor real"*. El hueco en
el ecosistema .NET MCP es real, trivial de ocupar con código ya escrito,
y con impacto desproporcionado en posicionamiento profesional.
