# Provider-Agnostic Tech Debt — Skills & Scripts

> Snapshot: 2026-05-02. Ref: Auditoria completa de vendor lock-in.
> Ultima actualizacion: post Era 193 (SaviaClaw DeepSeek migration).
> Este documento trackea la deuda tecnica restante tras las fases 1-3 de migracion.

## Providers disponibles en el host (2026-05-02)

| Provider | Via | Modelos | Coste /1M input |
|----------|-----|---------|----------------|
| **DeepSeek** | OpenCode | v4-pro (75% off), v4-flash | $0.435 / $0.14 |
| **Anthropic** | Claude Code / OpenCode | Claude Sonnet 4, Haiku 4.5 | $3.00 / $0.80 |
| **Qwen local** | Ollama | Qwen2.5:3b, Qwen2.5:7b (instalados), Qwen3.6 disponible | Gratis (local) |

## Skills — 51/92 con vendor references (55%)

No son bloqueantes de runtime porque las skills son documentos Markdown
interpretados por LLMs, no codigo ejecutable. Pero contienen instrucciones
que asumen Claude Code, lo que puede confundir a un LLM corriendo en OpenCode.

### BROKEN (requieren rewrite parcial) — 5 skills

| Skill | Problema |
|-------|----------|
| `overnight-sprint` | `claude --enable-auto-mode` (flag CLI exclusivo), `Claude Code 2026` |
| `context-rot-strategy` | `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (env var Claude Code), `opus-4-7` |
| `personal-vault` | Paths `~/.claude/rules/`, `~/.claude/instincts/`, exclusivos Claude Code |
| `sovereignty-auditor` | `.claude/settings.json`, `.claude/agent-memory/`, `API Anthropic` |
| `pr-agent-judge` | `claude-sonnet-4-6` hardcodeado como modelo |

### WARN (paths `.claude/` internos) — 46 skills

Referencias a `.claude/` que reflejan la estructura real del workspace.
El symlink `.opencode/hooks/` → `.claude/hooks/` hace que muchas de estas
referencias funcionen en OpenCode. La migracion completa requiere renombrar
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
Los otros 90 skills no tienen campo `compatibility`. Anadirlo es mecanico
(1 linea por SKILL.md) pero tedioso (90 archivos).

## Scripts — hallazgos ya resueltos

- `api.anthropic.com` → `$SAVIA_API_UPSTREAM` con fallback (5 scripts fixed)
- `$CLAUDE_PROJECT_DIR` sin fallback → verificado: los scripts usan fallback o computan el path
- `@anthropic-ai/claude-code` → es el nombre real del paquete npm, no es lock-in
- `call_claude()` hardcodeado en SaviaClaw → migrado a `llm_backend.py` (OpenCode + DeepSeek, Era 193)
- Nombre del servidor ("Lima") en codigo y docs → reemplazado por "host" (PII cleanup, Era 193)

## Lazy Loading & Context — OK

El sistema de lazy loading funciona por convencion (el LLM decide que leer).
Los 15 paths en la Lazy Reference de CLAUDE.md y los 10 de AGENTS.md existen.
No requiere fixes.

## .scm / .acm / .hcm — OK

- `.scm/`: 1128 recursos indexados (100%). 534 commands, 92 skills, 70 agents, 432 scripts.
- `.acm/` y `.hcm/`: son por-proyecto, su ausencia en raiz es por diseno.
- Auto-regeneracion activa en session-init + CI checks.
