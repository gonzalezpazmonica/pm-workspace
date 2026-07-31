# SaviaVaults — Servidor de Cúpulas de Contexto

> **Servidor MCP + A2A para vaults de conocimiento de agentes IA con almacenamiento git, búsqueda híbrida y firma de contenido.**

[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-22%2B-green.svg)](https://nodejs.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.7%2B-blue.svg)](https://www.typescriptlang.org)

SaviaVaults da a los agentes IA (Claude, GPT, Codex, Cursor) acceso seguro e inteligente a vaults de conocimiento locales. Es una **cúpula de contexto**: un repositorio versionado, indexado y firmado criptográficamente de todo lo que tu proyecto sabe — accesible mediante protocolos estándar (MCP + A2A) sin dependencia de la nube.

---

## Inicio Rápido

```bash
# Instalar globalmente
npm install -g savia-vaults

# Crear tu primer vault
savia-vaults init mi-conocimiento
cd vaults/mi-conocimiento

# Iniciar servidor MCP (Claude Code / Codex / Cursor se conectan automáticamente)
savia-vaults serve --transport mcp

# O iniciar servidor A2A (compartir contexto entre agentes)
savia-vaults serve --transport a2a --port 8923

# Buscar desde CLI
savia-vaults search "patrones de arquitectura" --path ./vaults/mi-conocimiento

# Estadísticas
savia-vaults stats --path ./vaults/mi-conocimiento
```

## ¿Qué es una Cúpula de Contexto?

Una **cúpula de contexto** es un repositorio estructurado de conocimiento que:
- **Versiona** el conocimiento como código (git-backed, cada escritura es un commit)
- **Firma** el contenido criptográficamente (recibos Ed25519 para trazabilidad)
- **Indexa** todo para búsqueda híbrida (BM25 + embeddings)
- **Expone** el conocimiento mediante protocolos estándar de IA (MCP + A2A)
- **Protege** contra fugas con sandbox de seguridad de 6 capas

Inspirado en [MCPVault](https://github.com/bitbonsai/mcpvault), [Cognithor](https://github.com/Alex8791-cyber/cognithor) y el patrón [context-dome](https://github.com/gonzalezpazmonica/pm-workspace) de Savia (SE-252).

## Arquitectura

```
Agentes IA (Claude, GPT, Codex, Cursor, Gemini)
        │ MCP (stdio)          │ A2A (HTTP/SSE)
        ▼                      ▼
┌─────────────────────────────────────────────┐
│           Servidor SaviaVaults               │
│  ┌───────────┐  ┌──────────┐  ┌──────────┐ │
│  │ Capa MCP  │  │Capa A2A  │  │   CLI    │ │
│  │9 herram.  │  │5 endpoints│  │ 4 cmds   │ │
│  └─────┬─────┘  └────┬─────┘  └────┬─────┘ │
│        │              │              │       │
│  ┌─────▼──────────────▼──────────────▼─────┐ │
│  │           Motor Principal               │ │
│  │  ┌────────┐ ┌────────┐ ┌────────────┐  │ │
│  │  │Búsqueda│ │Almacén │ │ Seguridad   │  │ │
│  │  │ BM25+  │ │ Git +  │ │Sandbox +    │  │ │
│  │  │Embed   │ │Contenido│ │Firmas       │  │ │
│  │  └────────┘ └────────┘ └────────────┘  │ │
│  └────────────────────────────────────────┘ │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│        Vault (Sistema de Archivos + Git)     │
│  vaults/{nombre}/                            │
│  ├── INDEX.md          (mapa de contenido)   │
│  ├── MAP.md            (tabla de enrutado)   │
│  ├── contexto/         (cúpulas de contexto) │
│  ├── conocimiento/     (conocimiento dominio)│
│  ├── decisiones/       (registros ADR)       │
│  └── .savia-vault      (metadatos + recibos) │
└─────────────────────────────────────────────┘
```

## Herramientas MCP

| Herramienta | Descripción | Parámetros |
|---|---|---|
| `vault_read` | Leer una nota por ruta | `path` (obligatorio) |
| `vault_write` | Crear/actualizar nota (git-commit + firma) | `path`, `content` (obligatorios), `message` |
| `vault_search` | Búsqueda BM25 con fragmentos | `query` (obligatorio), `pathPrefix`, `maxResults` |
| `vault_list` | Listar contenido del vault (árbol) | `path` (opcional) |
| `vault_stats` | Estadísticas del vault | — |
| `vault_index` | Reconstruir índice de búsqueda | — |
| `vault_diff` | Mostrar git diff de una nota | `path` (obligatorio) |
| `vault_log` | Mostrar historial git de una nota | `path` (obligatorio), `maxCount` |
| `vault_tags` | Listar etiquetas con conteos | — |

## Endpoints A2A

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/contexto/{vault}/{ruta}` | Obtener contexto por vault y ruta |
| `GET` | `/buscar?q={consulta}&vault={nombre}&maxResults={n}` | Buscar entre vaults |
| `POST` | `/compartir` | Compartir contexto con otro agente |
| `GET` | `/stats` | Estadísticas del vault |
| `GET` | `/health` | Verificación de salud |

## Modelo de Seguridad

| Control | Descripción |
|---|---|
| **Sandbox de rutas** | Rutas normalizadas a la raíz del vault — bloqueo de traversal (`..`, absolutas) |
| **Lista de denegación** | `.git`, `.obsidian`, `node_modules`, `.savia-vault`, `.trash` bloqueados a cualquier profundidad |
| **Lista de permisos** | Solo `.md`, `.yaml`, `.yml`, `.json`, `.txt`, `.canvas`, `.base` legibles |
| **Protección de symlinks** | Symlinks fuera del vault bloqueados (TOCTOU-safe) |
| **Límites de tamaño** | Archivos >10MB bloqueados (configurable) |
| **Límites de profundidad** | Rutas >10 niveles bloqueadas |
| **Firma de contenido** | Recibos Ed25519 en cada escritura para trazabilidad de conocimiento |

## Instalación

### Linux / macOS

```bash
npm install -g savia-vaults
```

O usar el script de instalación:

```bash
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/savia-vaults/main/scripts/install.sh | bash
```

### Windows (PowerShell)

```powershell
npm install -g savia-vaults
```

O usar el script de instalación:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gonzalezpazmonica/savia-vaults/main/scripts/install.ps1" | Invoke-Expression
```

### Requisitos
- Node.js 22+
- Git 2.40+
- npm 10+

## Desarrollo

```bash
git clone https://github.com/gonzalezpazmonica/savia-vaults.git
cd savia-vaults
npm install
npm run build
npm test
npm run test:coverage
```

## Licencia

MIT. Ver [LICENSE](LICENSE).

---

*Parte del ecosistema Savia — [pm-workspace](https://github.com/gonzalezpazmonica/pm-workspace)*
