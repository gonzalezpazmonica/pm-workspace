# Claude Code ↔ OpenCode — Hook Event Equivalence

> Provider-agnostic reference for hook event mapping between frontends.
> Ref: SPEC-127 (provider-agnostic migration), `.opencode/hooks/README.md`.

## Event mapping

| Claude Code event | OpenCode equivalent | Coverage |
|---|---|---|
| `PreToolUse` | `tool.execute.before` | savia-foundation.ts (5 guards nativos) + savia-gates bridge (26 .sh) |
| `PostToolUse` | `tool.execute.after` | savia-gates bridge (13 .sh) |
| `PostToolUseFailure` | — | Sin equivalente. Hooks huérfanos: `post-tool-failure-log`. |
| `UserPromptSubmit` | `chat.message` | savia-gates bridge (3 .sh) |
| `SessionStart` | `event: session.created` | savia-gates bridge (3 .sh) |
| `SessionEnd` | `event: session.deleted` | savia-gates bridge (1 .sh) |
| `Stop` | `event: session.stopped` | savia-gates bridge (8 .sh) |
| `PreCompact` | `experimental.session.compacting` | savia-gates bridge (1 .sh) |
| `PostCompact` | — | Sin equivalente. Hook huérfano: `scripts/post-compaction.sh`. |
| `SubagentStart` | `event: subagent.started` | savia-gates bridge (1 .sh) |
| `SubagentStop` | `event: subagent.completed` | savia-gates bridge (1 .sh) |
| `TaskCreated` | `event: task.created` | savia-gates bridge (1 .sh) |
| `TaskCompleted` | `event: task.completed` | savia-gates bridge (1 .sh) |
| `CwdChanged` | — | Sin equivalente. Hook huérfano: `cwd-changed-hook`. |
| `FileChanged` | — | Sin equivalente. Hook huérfano: `file-changed-staleness`. |
| `InstructionsLoaded` | — | Sin equivalente. Hook huérfano: `instructions-tracker`. |
| `ConfigChange` | — | Sin equivalente. Hook huérfano: `config-reload`. |

## Exclusive OpenCode events

| OpenCode event | Claude Code equivalent | Usage |
|---|---|---|
| `permission.ask` | — | savia-gates bridge (nuevo) |
| `command.execute.before` | — | savia-gates bridge (nuevo) |
| `hook: post-tool-message` | PostToolUse (parcial) | savia-gates bridge |

## Gap analysis

**6 events sin equivalente OpenCode (35% de 17):**
- `PostToolUseFailure`, `PostCompact`, `CwdChanged`, `FileChanged`, `InstructionsLoaded`, `ConfigChange`
- **Impacto:** Bajo. Son eventos de instrumentación/metadatos, no bloqueantes de seguridad.
- **Mitigación:** Los hooks huérfanos de estos eventos ejecutan lógica no crítica (logging, staleness checks, tracking) que se puede perder sin riesgo de seguridad.

**11 eventos con equivalente (65%):**
- Cobertura completa para todos los hooks de seguridad (Tier 1), sesión, y subagentes.

## Bridge architecture

El bridge `savia-gates` (`scripts/opencode-plugin/savia-gates/`) resuelve la
compatibilidad mediante:

1. **Manifest loader** (`lib/manifest.ts`): Lee `.claude/settings.json` y mapea
   eventos Claude Code → OpenCode.
2. **Shell bridge** (`lib/shell-bridge.ts`): Ejecuta hooks .sh vía Bun `$` shell API
   inyectando `CLAUDE_PROJECT_DIR=$PM_WORKSPACE_ROOT` como env var.
3. **Permission adapter** (`lib/permission.ts`): Convierte exit codes de hooks
   (0 = allow, 2 = block) a throws/returns de OpenCode.

## Estrategia de migración

1. **Fase 1 (completado):** 5 hooks Tier-1 portados a TypeScript nativo
   (`savia-foundation.ts`). Cobertura dual .sh + .ts.
2. **Fase 2 (completado):** Bridge `savia-gates` para los 61 hooks restantes.
3. **Fase 3 (planeado):** Portar hooks Tier-2 (session, memory, quality gates)
   a TypeScript nativo. Eliminar dependencia del bridge para hooks no críticos.
4. **Fase 4 (futuro):** Una vez que todos los hooks tengan port nativo,
   desactivar el bridge y eliminar el symlink `.opencode/hooks/`.
