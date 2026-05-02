# Provider-Agnostic Tech Debt — Skills & Scripts

> Snapshot: 2026-05-02. Ref: Auditoría completa de vendor lock-in.
> Este documento trackea la deuda técnica restante tras las fases 1-3 de migración.

## Skills — 51/92 con vendor references (55%)

No son bloqueantes de runtime porque las skills son documentos Markdown
interpretados por LLMs, no código ejecutable. Pero contienen instrucciones
que asumen Claude Code, lo que puede confundir a un LLM corriendo en OpenCode.

### BROKEN (requieren rewrite parcial) — 5 skills

| Skill | Problema |
|-------|----------|
| `overnight-sprint` | `claude --enable-auto-mode` (flag CLI), `Claude Code 2026` |
| `context-rot-strategy` | `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (env var), `opus-4-7` en tags |
| `personal-vault` | `~/.claude/rules/`, `~/.claude/instincts/`, `CLAUDE.md` paths |
| `sovereignty-auditor` | `.claude/settings.json`, `.claude/agent-memory/`, `API Anthropic` |
| `pr-agent-judge` | `claude-sonnet-4-6` hardcodeado como modelo |

### WARN (paths `.claude/` internos) — 46 skills

Referencias a `.claude/` que reflejan la estructura real del workspace.
El symlink `.opencode/hooks/` → `.claude/hooks/` hace que muchas de estas
referencias funcionen en OpenCode. La migración completa requiere renombrar
el directorio o actualizar referencias.

Top 5 por volumen de referencias:
| Skill | Refs `.claude/` |
|-------|----------------|
| `workspace-integrity` | 12 |
| `codebase-map` | 4 |
| `prompt-optimizer` | 5 |
| `diagram-generation` | 4 |
| `pbi-decomposition` | 4 |

### `compatibility: opencode` ausente — 90 skills

Solo `savia-identity` y `savia-memory` declaran `compatibility: opencode`.
Los otros 90 skills no tienen campo `compatibility`. Añadirlo es mecánico
(1 línea por SKILL.md) pero tedioso (90 archivos).

## Scripts — hallazgos ya resueltos

- `api.anthropic.com` → `$SAVIA_API_UPSTREAM` con fallback (5 scripts fixed)
- `$CLAUDE_PROJECT_DIR` sin fallback → verificado: los scripts usan fallback o computan el path
- `@anthropic-ai/claude-code` → es el nombre real del paquete npm, no es lock-in

## Lazy Loading & Context — OK

El sistema de lazy loading funciona por convención (el LLM decide qué leer).
Los 15 paths en la Lazy Reference de CLAUDE.md y los 10 de AGENTS.md existen.
No requiere fixes.

## .scm / .acm / .hcm — OK

- `.scm/`: 1126/1134 recursos indexados (99.6%). 8 deltas cosméticos.
- `.acm/` y `.hcm/`: son por-proyecto, su ausencia en raíz es por diseño.
- Auto-regeneración activa en session-init + CI checks.
