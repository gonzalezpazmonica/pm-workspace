---
context_tier: L3
token_budget: 900
spec: SE-333
---

# Agent Plugins / Agent Skills Compliance

> Política canónica de conformidad de skills para `agent-plugins.org` (spec
> v1.0.0, Working Draft) y `agentskills.io`. Pin a v1.0.0; cambios del estándar
> se vigilan con `ecosystem-watcher` (mensual).

## Referencias normativas

- **agent-plugins.org** — spec v1.0.0 (Working Draft). Estándar abierto
  vendor-neutral para empaquetar Agent Skills + MCP servers en plugins portables.
  TSC inicial: Amazon, Cursor, Microsoft, OpenAI, Vercel.
- **agentskills.io** — Agent Skills specification (`SKILL.md` con frontmatter
  `name`/`description` + `metadata`, `allowed-tools`).
- **modelcontextprotocol.io** — config declarativa MCP (`mcp.json`).

## Checklist canónico para una SKILL.md conforme

### `name` (requerido)

- 1–64 chars.
- Lowercase unicode alfanumérico + guiones (`-`).
- Sin guiones inicial, final ni consecutivos (`--`).
- DEBE ser idéntico al nombre del directorio que la contiene.

### `description` (requerido)

- 1–1024 chars.
- Describe QUÉ hace y CUÁNDO usarla (formato SE-209: "Usar cuando ...").
- Sin jerga interna no glosada.

### `metadata` (requerido para campos propios)

- Mapa **string→string** únicamente. Los campos propios de Savia van con
  prefijo de namespace `savia.`:

| Campo Savia (legacy top-level) | Metadata |
|---|---|
| `summary` | `savia.summary` |
| `maturity` | `savia.maturity` |
| `context` | `savia.context` |
| `context_cost` | `savia.context_cost` |
| `agent` | `savia.agent` |
| `category` | `savia.category` |
| `priority` | `savia.priority` |
| `loop_level` | `savia.loop_level` |
| `tags` (lista) | `savia.tags` = join por coma |
| `trigger.keywords` (lista) | `savia.trigger_keywords` = join por coma |
| `consumes` (lista) | `savia.consumes` = join por coma |
| `produces` (lista) | `savia.produces` = join por coma |

- Serialización a string es la ÚNICA opción compatible con "map from string
  keys to string values". Listas → `join(", ")`.

### `license` y `compatibility` (opcionales, top-level)

- SPDX recomendado. `compatibility` cuando aplica a un cliente específico.

### Progressive disclosure

- `scripts/`, `references/`, `assets/` al lado de `SKILL.md`.
- Savia mapea sus satélites existentes: `REFERENCE.md`/`DOMAIN.md`/`tests.md`
  equivalen a contenido bajo `references/` (sin renombrado obligatorio).

## Layout de paquete (plugin)

```
<repo-root>/                         ← plugin package root
├── plugin.json                      ← manifest Agent Plugins (portable)
├── skills -> .claude/skills/        ← symlink (resuelve dentro del root, §4.1)
└── com.savia.client/                ← extension namespace (owner-defined)
    ├── agents/                      ← espejo (FUERA de Agent Plugins v1)
    ├── commands/
    ├── hooks/
    └── rules/
```

- `com.savia.client` es namespace provisional. El reverse-domain definitivo se
  fija ANTES de cualquier publicación externa.
- Agents / commands / hooks / rules NO son portables en v1 (spec §Design
  Decisions) — van a la extension namespace, que otros clientes ignoran sin
  romper conformidad.

## MCP portable

- `mcp.json` (raíz) declara transporte `type: stdio` + `command` como token
  único (no shell) + `args`/`env`/`cwd` separados + placeholders
  `${PLUGIN_ROOT}`/`${PLUGIN_DATA}`.
- `.claude/mcp.json` (formato Claude) y `.claude-plugin/plugin.json` (formato
  Claude Code) coexisten sin tocarse.

## Enforcement

- Auditoría: `bash scripts/skill-audit.sh --agent-plugins [--strict] [--json]`.
- Gate CI: corre `--strict` y falla si un PR añade skills no conformes.
- Drift de la spec: pin v1.0.0; `ecosystem-watcher` mensual vigila cambios.

## Fuera de alcance

- Portabilidad de comportamiento (hooks, sandbox, MCP varían por cliente): la
  conformidad declarada NO garantiza ejecución idéntica cross-client.
- `allowed-tools` (experimental) — adoptar solo cuando el soporte madure.
