# Spec: SE-333 — Cumplimiento Agent Plugins / Agent Skills: skills portables + package manifest

**Status:** APPROVED
**Fecha:** 2026-08-16
**Fecha aprobación:** 2026-08-16 (operadora, sesión opencode)
**Area:** Interoperability / Skills packaging / Standards
**Estimación:** ~18h (4 slices)
**Inspirado por:** agent-plugins.org (spec v1.0.0, Working Draft) + agentskills.io (Agent Skills specification)

**Developer Type:** agent-single
**Asignado a:** claude-agent

---

## Origen

Análisis de `agent-plugins.org` (v1.0.0, Working Draft): estándar abierto y
vendor-neutral para empaquetar componentes reutilizables en plugins portables.
Define un piso de interoperabilidad mínimo para dos tipos de componente ya
estandarizados fuera del proyecto:

- **Agent Skills** (`agentskills.io`): formato `SKILL.md` con frontmatter
  `name`/`description` (+ `license`, `compatibility`, `metadata`, `allowed-tools`).
- **MCP servers** (`modelcontextprotocol.io`): config declarativa `mcp.json`.

Su Technical Steering Committee inicial incluye Core Maintainers de Amazon,
Cursor, Microsoft, OpenAI y Vercel — es el formato hacia el que convergen los
runtimes (Claude Code, Codex, Cursor, Gemini CLI, OpenCode, Goose, Windsurf).

Savia hoy:

- **127 skills** en `.claude/skills/` (`.opencode/skills` es symlink a esta).
- Todos los `name` cumplen lowercase-kebab (válidos). 127/127 tienen `name` y `description`.
- **Pero** el frontmatter extiende con campos propios top-level: `summary`, `maturity`,
  `context`, `context_cost`, `agent`, `category`, `tags` (lista), `priority`, `trigger`
  (objeto con `keywords` lista), `loop_level`, `consumes`, `produces`. Ninguno está en
  el estándar; el estándar exige que los metadatos arbitrarios vayan bajo un mapa
  `metadata` **string→string**.
- Solo **5/127** skills tienen `license`/`metadata`/`compatibility`.
- No hay `plugin.json` Agent Plugins (existe `.claude-plugin/plugin.json`, formato nativo
  de Claude Code, incompatible).
- No hay `mcp.json` portable (existe `.claude/mcp.json`, formato Claude con `command`/`args`,
  sin `type` de transporte declarado).
- **83 agents, 570 commands, 108 hooks, rules** — explícitamente FUERA del alcance de
  Agent Plugins v1 (spec §Design Decisions: "commands, hooks, agents, rules... too
  client-specific for a stable portable contract").

Precedente interno: **SPEC-143** (2026-05-23) intentó una auditoría de conformidad
SKILL.md → ABORTADA porque la premisa de research era falsa (ninguna skill supera 500
líneas; Rule #11 capa a 150). El valor residual se absorbió en `scripts/skill-audit.sh`.
Este spec va **más allá**: cumplimiento a nivel de paquete (manifest + layout +
frontmatter + MCP), no solo conteo de líneas.

## Problema actual

- Las skills de Savia no son cargables por otros clientes sin adaptación: los campos
  propios top-level rompen el contrato cerrado del frontmatter estándar.
- No existe manifest de descubrimiento portable (`plugin.json`).
- No hay verificación sistemática de conformidad contra el estándar (el drift es silencioso).
- La configuración MCP no declara servidores por defecto; cada operador la configura localmente.

## Diseño

### 1. Documento de política `docs/rules/domain/agent-plugins-compliance.md`

Checklist canónico citando agent-plugins.org y agentskills.io:
- `name`: 1–64 chars, lowercase unicode alfanumérico + guiones, sin guiones
  inicial/final/consecutivos, igual al nombre del directorio.
- `description`: 1–1024 chars, describe QUÉ hace y CUÁNDO usarla (ya cubierto por SE-209).
- Campos propios → `metadata` (mapa string→string) con prefijo de namespace `savia.*`.
- `license` (SPDX recomendado) y `compatibility` cuando aplican.
- Progressive disclosure: `scripts/`, `references/`, `assets/` (Savia ya usa
  `REFERENCE.md`, `DOMAIN.md`, `tests.md` — mapear a `references/`).

### 2. Normalización de frontmatter (migración string→string)

Savia mantiene `name` + `description` top-level (estándar). Los campos propios migran a `metadata`:

| Campo actual (top-level) | Tipo | Migración a `metadata` |
|---|---|---|
| `summary` | string | `savia.summary` |
| `maturity` | string | `savia.maturity` |
| `context` | string | `savia.context` |
| `context_cost` | string | `savia.context_cost` |
| `agent` | string | `savia.agent` |
| `category` | string | `savia.category` |
| `priority` | string | `savia.priority` |
| `loop_level` | string | `savia.loop_level` |
| `tags` | lista | `savia.tags` = join por coma |
| `trigger.keywords` | lista | `savia.trigger_keywords` = join por coma |
| `consumes` / `produces` | lista | `savia.consumes` / `savia.produces` = join por coma |
| `license` | — | top-level (estándar) |
| `compatibility` | — | top-level (estándar) |

**Impacto interno a absorber**: `scripts/skill-routing-index.sh`,
`scripts/skill-keyword-detector.sh`, `scripts/skills-md-generate.sh`,
`scripts/skill-loader.sh` leen `tags`/`trigger`/`agent` top-level. Deben leer de
`metadata.savia.*` (o soportar ambos con warning de deprecación). La serialización a
string es la única opción compatible con la constraint "map from string keys to string values".

### 3. Package layout + `plugin.json` (raíz del repo como plugin)

Agent Plugins descubre skills en `skills/` (hijos inmediatos con `SKILL.md`). Savia las
tiene en `.claude/skills/`. Propuesta **no destructiva**:

```
<repo-root>/                         ← plugin package root
├── plugin.json                      ← manifest Agent Plugins (CREATE)
├── skills -> .claude/skills/        ← symlink (resuelve dentro del root, permitido §4.1)
└── com.savia.client/                ← extension namespace (CREATE)
    ├── agents/                      ← espejo de .claude/agents (fuera de v1, owner-defined)
    ├── commands/
    ├── hooks/
    └── rules/
```

`plugin.json` (cerrado, campos permitidos §5):

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "pm-workspace",
  "version": "2.24.0",
  "description": "Complete PM automation with AI agents — Azure DevOps, Jira, Scrum, SDD pipeline",
  "license": "MIT",
  "keywords": ["project-management", "agile", "sdd", "azure-devops"],
  "extensions": {
    "com.savia.client": { "agents": 83, "commands": 570, "hooks": 108 }
  }
}
```

- `com.savia.client` es namespace provisional (placeholder) — el reverse-domain definitivo
  se fija antes de cualquier publicación externa. Los agentes/commands/hooks/rules viven
  ahí como extensión owner-defined; otros clientes los ignoran sin romper conformidad (§8).
- `skills -> .claude/skills/` mantiene `.claude/skills/` como fuente de verdad para Claude
  Code; el symlink expone el layout portable sin duplicar 127 skills.

### 4. `mcp.json` portable

Crear `mcp.json` en formato Agent Plugins sin servidores preconfigurados (igual que `.claude/mcp.json`
con `command`/`args` bash -c). El formato portable exige `type` + `command` como token
único (no shell), con `args`/`env`/`cwd` separados y placeholders `${PLUGIN_ROOT}`/`${PLUGIN_DATA}`:

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json",
  "mcpServers": {}
}
```

**Nota de honestidad**: el `bash -c` actual envuelve `nvm` para resolver `node`. El formato
portable no admite `command` como shell. Se requiere que el binario node resuelva vía
`PATH` del cliente (o fijar ruta absoluta) — decisión operativa, no bloqueante.

### 5. Script de auditoría + gate CI

Extender `scripts/skill-audit.sh` (ya existe) con modo `--agent-plugins`:
- Valida `name` regex y unicidad.
- Valida `description` 1–1024 chars.
- Flaggea campos propios top-level fuera de `metadata` (warn → error en `--strict`).
- Valida `plugin.json` contra el schema cerrado (dos campos requeridos `$schema`+`name`,
  constraints de name, `extensions` como objeto).
- Valida `mcp.json` (transporte declarado, paths `./` contenidos).
- `--json` para CI; exit 1 si incumplimiento nuevo.

Gate: pre-commit hook o GitHub Action que corre `skill-audit.sh --agent-plugins --strict`
y falla si un PR añade skills no conformes.

### 6. Tests BATS

`tests/test-se-333-agent-plugins.bats`: 10+ casos (name válido/inválido, description
excedida, metadata tipo string, plugin.json schema, mcp transporte, path escape,
symlink contenido, extension namespace ignorado, desconocido top-level no fatal).

## Acceptance criteria

- [ ] AC-1 `docs/rules/domain/agent-plugins-compliance.md` cita agent-plugins.org + agentskills.io con el checklist canónico.
- [ ] AC-2 Los campos propios de las 127 skills migran a `metadata.savia.*` (string→string); `name`/`description` quedan top-level.
- [ ] AC-3 `plugin.json` Agent Plugins creado en la raíz con `$schema` + `name` válidos y `extensions.com.savia.client`.
- [ ] AC-4 `skills -> .claude/skills/` symlink resuelve dentro del root (contención §4.1 verificada por script).
- [ ] AC-5 `mcp.json` portable creado sin servidores ni rutas operativas preconfiguradas.
- [ ] AC-6 `scripts/skill-audit.sh --agent-plugins` valida name/description/metadata/plugin.json/mcp.json con salida `--json`.
- [ ] AC-7 Los scripts de routing (routing-index, keyword-detector, skills-md-generate, skill-loader) leen `metadata.savia.*` sin romper el catálogo SKILLS.md.
- [ ] AC-8 Tests BATS 10+ cubren los casos del diseño §6.
- [ ] AC-9 Gate CI falla si un PR añade skills no conformes (modo `--strict`).

## Ficheros

| Acción | Path |
|---|---|
| CREATE | `docs/rules/domain/agent-plugins-compliance.md` |
| MODIFY | `scripts/skill-audit.sh` (modo `--agent-plugins`) |
| MODIFY | `scripts/skill-routing-index.sh`, `skill-keyword-detector.sh`, `skills-md-generate.sh`, `skill-loader.sh` (leer `metadata.savia.*`) |
| CREATE | `plugin.json` (Agent Plugins) |
| CREATE | `skills` symlink → `.claude/skills/` |
| CREATE | `mcp.json` (Agent Plugins) |
| CREATE | `com.savia.client/` (extension namespace placeholder) |
| MODIFY | 127 `SKILL.md` (frontmatter → `metadata`) |
| CREATE | `tests/test-se-333-agent-plugins.bats` |
| CREATE | `docs/specs/SE-333-agent-plugins-compliance.spec.md` |

## No modifica

- `.claude-plugin/plugin.json` (formato nativo Claude Code) — coexiste; es el canal de
  instalación de Claude, no se toca.
- `.claude/mcp.json` (formato Claude) — se mantiene como binding nativo; el `mcp.json`
  portable es adicional.
- Agentes (83), commands (570), hooks (108), rules — fuera de Agent Plugins v1; solo se
  espejan bajo `com.savia.client/` sin migración.
- `.claude/skills/` sigue siendo la fuente de verdad para Claude Code (el symlink no la
  reemplaza).

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| skills | `.claude/skills/` (real) | `.opencode/skills` (symlink → `.claude/skills/`) |
| audit | `scripts/skill-audit.sh` | Mismo script bash |
| manifest | `plugin.json` (nuevo, portable) | Consumible por clientes Agent Plugins |
| tests | BATS | Mismo runner bash |

### Verification protocol

- [ ] `bash scripts/skill-audit.sh --agent-plugins --json` corre en <5s sobre 127 skills.
- [ ] `scripts/skills-md-generate.sh` regenera `SKILLS.md` sin pérdida de campos tras la migración.
- [ ] `skills -> .claude/skills/` resuelve dentro del root (test de contención §4.1).
- [ ] No se añaden hooks nuevos (reusa skill-audit existente).

### Portability classification

- [x] **PURE_BASH**: lógica en bash + docs + BATS. El manifest/`mcp.json` son JSON declarativos.

## Riesgos y mitigación

- **Falsa portabilidad**: que el frontmatter sea conforme no garantiza que Cursor/Codex
  ejecuten igual (hooks, sandbox, MCP varían). Mitigación — smoke test "cargar skill en
  runtime alternativo" si hay tooling disponible; de lo contrario, el cumplimiento se
  limita a formato (conformidad declarada, no comportamiento).
- **Ruptura del routing interno** (SE-152): la migración `tags`/`trigger` → `metadata`
  toca scripts en producción. Mitigación — lectura dual con warning de deprecación
  durante 30 días antes de eliminar el top-level.
- **Drift de la spec**: agent-plugins.org es Working Draft. Mitigación — pin a v1.0.0 en
  el doc de política; `ecosystem-watcher` (mensual) vigila cambios.
- **Namespace provisional**: `com.savia.client` es placeholder. No publicar hasta fijar
  reverse-domain real.

## Follow-up candidates

1. **MCP catalog portable** — extender el `mcp.json` con servidores opcionales
   (github, azure-devops) cuando el transporte stdio/streamable-http esté resuelto.
2. **Smoke test cross-runtime** — cargar una skill en Codex/Cursor/Gemini CLI para
   verificar comportamiento real, no solo formato (depende de tooling Tier 3).
3. **Registro de plugin** — evaluar publicar `pm-workspace` como plugin Agent Plugins
   en un registry/marketplace cuando exista (hoy la distribución es client-owned, §spec).
4. **allowed-tools experimental** — adoptar `allowed-tools` en skills de alto riesgo
   cuando el soporte cross-client madure.

## Lesson learned (potencial)

> SPEC-143 fracasó por auditar el síntoma (líneas de body) sobre una premisa falsa.
> SE-333 audita el contrato real (manifest + frontmatter + layout + MCP) y reconoce
> explícitamente el límite de portabilidad: commands/agents/hooks/rules NO son portables
> en v1 — van a la extension namespace, no al core. La portabilidad de Savia es incremental
> (skills + MCP), no total.
