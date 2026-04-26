# Regla: OpenCode ↔ Savia bridge

> Permite operar pm-workspace desde OpenCode v1.14 sin perder hooks, AUTONOMOUS_REVIEWER ni la base instalada de skills/agents. Vigente desde SE-077 Slice 1+2.

## Cuándo usar

- Plan B operativo cuando Anthropic restrinja Claude Code (Pro→Max ya en abril 2026, API-only previsto 6-18 meses)
- Sesiones donde necesitas el modelo via OpenAI/Gemini/local LLM en lugar de Anthropic
- Tests de equivalencia cross-frontend (canary mensual)

## Cuándo NO usar

- Operación principal: Claude Max sigue siendo frontend default (esto es plan B, no migración)
- Casos `API down` totales: usar SPEC-122 emergency-mode (LocalAI), no OpenCode
- Tareas con dependencia hardware GPU (Era 190+)

## Instalación

```bash
# Instala OpenCode v1.14.x en ~/.savia/opencode/ y enlaza el plugin savia-gates
bash scripts/opencode-install.sh

# Versión específica
bash scripts/opencode-install.sh --version 1.14.25

# Sólo re-enlazar el plugin (binary ya instalado)
bash scripts/opencode-install.sh --link-only

# Dry-run — muestra el plan sin tocar nada
bash scripts/opencode-install.sh --dry-run

# Desinstalar
bash scripts/opencode-install.sh --uninstall
```

Tras la instalación, el plugin escribe un manifest `~/.savia/opencode/plugins/savia-gates/manifest.json` que la herramienta de parity-audit usa para detectar gaps.

## Arquitectura

OpenCode carga el plugin TypeScript `savia-gates` en cada sesión. El plugin lee `.claude/settings.json` (mismo origen que Claude Code) y construye un mapa evento→hooks en memoria. Cada vez que OpenCode dispara un evento (`tool.execute.before`, `chat.message`, `permission.ask`, etc.), el plugin invoca los `.sh` correspondientes vía Bun's `$` shell — los hooks bash se ejecutan **sin modificar**.

| Evento Claude Code | Handler OpenCode |
|---|---|
| `PreToolUse` | `tool.execute.before` |
| `PostToolUse` | `tool.execute.after` |
| `UserPromptSubmit` | `chat.message` |
| `SessionStart` | `event:session.created` |
| `SessionEnd` | `event:session.deleted` |
| `Stop` | `event:session.stopped` |
| `SubagentStart`/`SubagentStop` | `event:subagent.*` |
| `TaskCreated`/`TaskCompleted` | `event:task.*` |
| `PreCompact` | `experimental.session.compacting` |

Eventos sin binding nativo (`Notification`, etc.) quedan documentados como `# opencode-binding: NOT_EXPOSED — <razón>` en el header del hook bash. La parity-audit los excluye del gap.

## Garantías de seguridad (autonomous-safety)

- ❌ El plugin NUNCA hace `git push`, `gh pr merge`, `--force`
- ❌ El plugin NUNCA aprueba un PR autónomamente
- ✅ `permission.ask` retorna `deny` para acciones destructivas en branches `agent/*` o `spec-*`
- ✅ AUTONOMOUS_REVIEWER respetado vía variable de entorno (mismo contrato que Claude Code)
- ✅ Audit log append-only en `~/.savia/audit/savia-gates.jsonl`

## Parity audit + canary

```bash
# Reporte de gap (texto)
bash scripts/opencode-parity-audit.sh

# Como JSON
bash scripts/opencode-parity-audit.sh --json

# Tras instalar, capturar el gap actual como baseline
bash scripts/opencode-parity-audit.sh --baseline

# Verificar regresión vs baseline
bash scripts/opencode-parity-audit.sh --check

# Canary mensual (compara equivalencia OpenCode vs Claude Code)
bash scripts/opencode-monthly-canary.sh --spec SE-073 --report-only
```

**Re-baseline post-instalación**: el baseline inicial commiteado refleja el estado pre-plugin (gap=N). Tras `bash scripts/opencode-install.sh` y la primera carga del plugin, ejecutar `--baseline` de nuevo y commitear el nuevo número.

## Pre-requisitos cumplidos

OpenCode v1.14.25 (latest abril 2026), Bun runtime (instalado por OpenCode), `.claude/settings.json` estable, AUTONOMOUS_REVIEWER configurado, AGENTS.md generado (SE-078).

## Referencias

- SE-077 spec — `docs/propuestas/SE-077-opencode-replatform-v114.md`
- SE-078 AGENTS.md cross-frontend — `docs/propuestas/SE-078-agents-md-cross-frontend.md`
- `https://github.com/sst/opencode` v1.14.25 (2026-04-25)
- `docs/rules/domain/autonomous-safety.md` — gates inviolables
- `docs/rules/domain/agents-md-source-of-truth.md` — SE-078
