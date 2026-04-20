---
status: PROPOSED
---

# ADR: Claude Connectors vs MCP — Evaluación de Arquitectura de Integraciones

> **Estado:** Propuesta · **Fecha:** 2026-03-06 · **Autor:** Savia
> **Contexto:** pm-workspace v2.20.2 (396+ comandos, 31 agentes, 41 skills)

---

## 1. Contexto

pm-workspace tiene ~40 comandos que dependen de herramientas externas (Slack, GitHub, Jira, Notion, Sentry, Figma, Google Drive, Azure DevOps, Linear). Hoy la arquitectura asume que el usuario configura MCP servers manualmente y los comandos los invocan via tool_use. El backlog estratégico plantea evaluar si Claude Connectors (lanzados julio 2025, 200+ en el directorio a febrero 2026) simplifican esta arquitectura.

### Lo que pm-workspace ya tiene

- `connectors-config.md`: regla con constantes de configuración por conector (Slack, GitHub, Sentry, Atlassian, GDrive, Notion, Linear, Figma).
- `mcp-migration.md`: guía de migración REST/CLI → MCP para Azure DevOps.
- `recommended-mcps.md`: catálogo curado de 12 MCPs del ecosistema claude-code-templates.
- `.claude/mcp.json`: vacío (los MCP se conectan bajo demanda con `/mcp-server start`).
- ~40 comandos que referencian operaciones con herramientas externas.
- `mcp-browse` y `mcp-recommend`: comandos para explorar y recomendar MCPs.

---

## 2. Hallazgo clave: Connectors = MCP

La investigación revela que **no hay dilema real**. Los Claude Connectors no son una tecnología alternativa a MCP; son exactamente MCP servers que Anthropic ha revisado, publicado en un directorio curado, y envuelto con OAuth gestionado.

Cita del FAQ oficial: los Connectors son "a single hub where users can discover MCP servers that Anthropic has reviewed". Están construidos sobre el Model Context Protocol y listados en el Connector Directory.

### Relación técnica

```
┌─────────────────────────────────────────────┐
│              Model Context Protocol (MCP)     │  ← Estándar abierto
│  ┌─────────────┐  ┌──────────────────────┐  │
│  │ MCP Servers  │  │ Claude Connectors    │  │  ← Implementaciones
│  │ (community)  │  │ (Anthropic-reviewed) │  │
│  └─────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────┘
         │                    │
    Claude Code          Claude Code
    Claude Desktop       Claude.ai
    API (beta)           Claude Desktop
                         Claude Mobile
```

**Connectors = MCP servers revisados + OAuth gestionado + directorio unificado.**

---

## 3. Comparativa detallada

### 3.1 Onboarding del usuario

| Aspecto | MCP manual | Connector |
|---|---|---|
| Instalación | `claude mcp add --transport http nombre url` | 1 clic en claude.ai/settings/connectors |
| Autenticación | Manual (OAuth flow, tokens, `/mcp`) | OAuth gestionado por Anthropic |
| Descubrimiento | Hay que conocer la URL del server | Directorio visual con 200+ opciones |
| Requiere terminal | Sí | No |
| Plan mínimo | Cualquiera (incluso free para community) | Free (directorio), Pro+ (custom) |

**Veredicto:** Para un PM no técnico (público principal de pm-workspace), los Connectors eliminan la barrera de entrada más grande: la configuración en terminal.

### 3.2 Disponibilidad por plataforma

| Plataforma | MCP servers | Connectors |
|---|---|---|
| Claude Code | Sí (stdio + HTTP + SSE) | Sí (auto-sync desde claude.ai) |
| Claude.ai (web) | Solo custom (Pro+) | Sí (nativo) |
| Claude Desktop | Sí (local config) | Sí (auto-sync) |
| Claude Mobile | No | Sí |
| API (Messages) | Sí (beta `mcp-client-2025-11-20`) | Via MCP connector en API |

**Dato clave:** Los Connectors configurados en claude.ai están automáticamente disponibles en Claude Code via `ENABLE_CLAUDEAI_MCP_SERVERS` (true por defecto). No hay que configurar nada dos veces.

### 3.3 Cobertura de herramientas que usa pm-workspace

| Herramienta | Connector oficial | MCP community | Notas |
|---|---|---|---|
| GitHub | Sí | Sí | Connector nativo de Anthropic |
| Slack | Sí | Sí | Connector nativo |
| Notion | Sí | Sí | Connector nativo |
| Google Drive | Sí | Sí | Connector nativo |
| Gmail | Sí | Sí | Connector nativo |
| Google Calendar | Sí | Sí | Connector nativo |
| Jira (Atlassian) | Sí | Sí | Connector nativo |
| Confluence | Sí | Sí | Vía Atlassian connector |
| Figma | Sí | Sí | Connector nativo |
| Sentry | Sí | Sí | Connector nativo |
| Linear | Sí | Sí | Connector en directorio |
| Azure DevOps | **No** | Sí (community) | Solo MCP community |
| Stripe | Sí | Sí | Connector nativo |
| DocuSign | Sí | No | Solo Connector |
| Elasticsearch | No | Sí | Solo MCP community |
| PostgreSQL | No | Sí (DBHub) | Solo MCP community |

**Resultado:** 11/12 herramientas principales de pm-workspace tienen Connector oficial. Solo Azure DevOps queda exclusivamente en MCP community.

### 3.4 Capacidades técnicas

| Capacidad | MCP | Connectors |
|---|---|---|
| Tool calling | Sí | Sí (son MCP) |
| Resources (@ mentions) | Sí | Sí |
| Prompts (como /commands) | Sí | Sí |
| Tool Search (lazy loading) | Sí (auto >10% contexto) | Sí |
| Scopes (local/project/user) | Sí (3 niveles) | Solo user (global) |
| Custom auth (API keys) | Sí (--env, --header) | Solo OAuth |
| Managed config (enterprise IT) | Sí (`managed-mcp.json`) | Sí (admin panel) |
| Timeout | Configurable (`MCP_TIMEOUT`) | 300s fijo (claude.ai/Desktop) |
| Max output tokens | 25,000 (configurable) | 25,000 |
| Stdio (local process) | Sí | No (solo remote HTTP) |
| `.mcp.json` (compartido en git) | Sí (project scope) | No |

### 3.5 Implicaciones para pm-workspace como proyecto open-source

| Factor | MCP puro | Connectors | Híbrido |
|---|---|---|---|
| Reproducibilidad | `.mcp.json` en el repo | Depende de cada usuario | `.mcp.json` + docs |
| CI/CD (GitHub Actions) | MCP via API beta | No aplicable | MCP en CI |
| Onboarding nuevos contributors | Manual terminal | 1 clic | Docs claros + ambas vías |
| Control de versiones | Sí (`project` scope) | No | Parcial |
| Offline/air-gapped | Sí (stdio local) | No | Según caso |

---

## 4. Análisis de impacto en pm-workspace

### 4.1 Comandos que se benefician directamente

Los ~40 comandos con integración externa se dividen en:

**Tier 1 — Connector disponible, onboarding trivial (11 servicios):** `/slack-search`, `/notify-slack`, `/github-issues`, `/github-activity`, `/repos-*`, `/notion-sync`, `/gdrive-upload`, `/jira-sync`, `/confluence-publish`, `/figma-extract`, `/sentry-*`, `/inbox-check`.

**Tier 2 — Solo MCP community (2 servicios):** Azure DevOps (`/sprint-status`, `/pipeline-*`, `/repos-*`), Elasticsearch.

**Tier 3 — Solo local/scripts:** operaciones de Analytics OData, capacities, burndown (ya documentadas en `mcp-migration.md` como funciones sin equivalente MCP).

### 4.2 Lo que NO cambia

- La arquitectura interna de comandos no cambia: siguen invocando MCP tools.
- Los comandos no necesitan saber si el MCP server viene de un Connector o de configuración manual.
- Las reglas de `connectors-config.md` siguen siendo válidas (son constantes de proyecto).
- El `.claude/mcp.json` sigue vacío (los servers se conectan bajo demanda).

### 4.3 Lo que SÍ cambia

- **Documentación de onboarding**: en vez de instrucciones de terminal, link a claude.ai/settings/connectors.
- **`recommended-mcps.md`**: actualizar para distinguir "Connectors oficiales" de "MCPs community".
- **`connectors-config.md`**: añadir nota sobre la auto-sincronización claude.ai → Claude Code.
- **Guías por vertical**: simplificar la sección "Prerequisitos" de cada guía.

---

## 5. Decisión recomendada: Estrategia Híbrida

### Recomendación

**Adoptar Connectors como vía primaria de onboarding, mantener MCP como base técnica.**

No hay migración que hacer — Connectors ya son MCP. Lo que cambia es cómo documentamos y guiamos al usuario.

### Principios

1. **Connector-first para usuarios finales** — Si existe Connector oficial, recomendar esa vía en las guías. Es 1 clic vs 1 comando de terminal.

2. **MCP-first para developers y CI** — Para contribuidores del repo, CI/CD, y entornos air-gapped, mantener la configuración via `.mcp.json` y `claude mcp add`.

3. **Sin lock-in** — Los comandos de pm-workspace no distinguen entre Connector y MCP manual. Ambos exponen los mismos tools. El usuario elige su vía.

4. **Azure DevOps sigue en MCP community** — No hay Connector oficial. Mantener `mcp-migration.md` y la configuración manual. Monitorizar el directorio de Connectors para cuando aparezca.

### Acciones concretas

| Acción | Prioridad | Fichero(s) afectados |
|---|---|---|
| Actualizar `recommended-mcps.md` con sección "Connectors oficiales" | Alta | `docs/recommended-mcps.md` |
| Añadir nota de auto-sync en `connectors-config.md` | Alta | `docs/rules/domain/connectors-config.md` |
| Crear guía rápida "Conectar herramientas en 1 minuto" | Media | `docs/guides/guide-connectors-quickstart.md` |
| Actualizar prerequisitos en guías existentes | Media | `docs/guides/guide-*.md` |
| Documentar `ENABLE_CLAUDEAI_MCP_SERVERS` en CLAUDE.md | Baja | `CLAUDE.md` |

### Lo que NO se recomienda hacer

- **No crear una capa de abstracción sobre Connectors.** Son MCP. No añade valor envolver algo que ya es un estándar abierto.
- **No deprecar la configuración MCP manual.** Hay casos legítimos (Azure DevOps, entornos enterprise con `managed-mcp.json`, CI/CD).
- **No crear comandos `/connector-*`.** Los comandos existentes (`/mcp-browse`, `/mcp-recommend`, `/mcp-server`) ya cubren el descubrimiento y la gestión.

---

## 6. Riesgo y mitigación

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Anthropic elimina un Connector que usamos | Baja | Medio | El usuario puede volver a MCP manual en 1 comando |
| Azure DevOps nunca tiene Connector | Media | Bajo | Ya funciona con MCP community |
| Connector tiene menos tools que MCP community | Baja | Bajo | Documentar diferencias y recomendar el más completo |
| OAuth del Connector caduca en sesiones largas | Media | Bajo | Re-autenticar es 1 clic; Claude Code hace refresh automático |

---

## 7. Conclusión

El dilema "Connectors vs MCP" es un falso dilema: los Connectors son MCP con mejor UX de onboarding. pm-workspace no necesita migrar nada internamente — solo actualizar documentación para que los usuarios no técnicos descubran la vía más fácil (1 clic) y los técnicos sepan que también pueden usar la terminal.

La inversión necesaria es documental, no arquitectónica. Estimación: 1 PR con cambios en 5-8 ficheros de documentación.
