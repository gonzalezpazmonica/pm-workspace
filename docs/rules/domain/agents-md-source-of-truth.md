# Regla: AGENTS.md source of truth

> Define cómo se mantiene `AGENTS.md` (el espejo cross-frontend) sin perder coherencia con `.claude/agents/*.md`. Vigente desde SE-078.

## Source of truth

`.claude/agents/*.md` con su frontmatter Anthropic-specific es el **único origen autoritativo**. Los agentes se editan ahí. `AGENTS.md` en el repo root es **derivado, jamás se edita a mano**.

## Por qué existe AGENTS.md

OpenCode v1.14, Codex, Cursor y otros frontends modernos leen `AGENTS.md` desde el repo root como contexto. Sin este espejo, los agentes que escribimos hoy serían Claude-Code-only (vendor lock-in via formato).

`agents.md/` (spec emergente) NO define un schema parseable canonical — los frontends lo tratan como contexto markdown libre. Por eso pinneamos nuestra propia tabla con 5 columnas (`Name | Model | Permission | Tools | Description`).

## Cuándo regenerar

Tres mecanismos, en este orden:

1. **Stop hook automático** (`.claude/hooks/agents-md-auto-regenerate.sh`): si la sesión modificó `.claude/agents/*.md`, regenera `AGENTS.md` async al cerrar la sesión.
2. **Manual**: `bash scripts/agents-md-generate.sh --apply`
3. **Pre-push**: pr-plan G14 (`agents-md-drift-check.sh`) bloquea PRs con drift.

## Drift policy

`scripts/agents-md-drift-check.sh` corre en pr-plan G14 y en CI. Falla con exit 1 si:
- `AGENTS.md` ausente
- Hay un agente nuevo en `.claude/agents/` no propagado
- Hay un entry stale para un agente borrado
- `AGENTS.md` fue editado a mano (no coincide con la salida del generador)

La salida en `--check` muestra un diff unified de las primeras 40 líneas para diagnóstico rápido.

## Lo que NO se hace

- NO editar `AGENTS.md` a mano (siempre regenerar)
- NO añadir campos no presentes en el frontmatter de los agentes
- NO añadir narrativa por agente (eso va en el body de `.claude/agents/<name>.md`)
- NO sustituir `.claude/agents/*.md` por AGENTS.md como fuente
- NO migrar el formato Anthropic-specific a otro estándar (la doble fuente es intencional)

## Cross-frontend contract

| Frontend | Lectura |
|---|---|
| Claude Code | `.claude/agents/*.md` directamente |
| OpenCode v1.14 | `AGENTS.md` (root) + `.opencode/agents/` symlink (fallback) |
| Codex / Cursor | `AGENTS.md` (root) como contexto freeform |

Si upstream `agents.md/` define un schema canonical más adelante, migrar via spec separado.

## Tamaño estimado

65 agentes × ~180 bytes/row ≈ 12 KB. Si supera 30 KB, considerar truncar `Description` aún más o partir en `AGENTS.md` por categoría (architecture/development/quality/...) — fuera de scope para SE-078.

## Referencias

- SE-078 spec — `docs/propuestas/SE-078-agents-md-cross-frontend.md`
- SE-077 OpenCode replatform — `docs/propuestas/SE-077-opencode-replatform-v114.md`
- SPEC-114 (SUPERSEDED por SE-078)
- `https://agents.md/` — spec emergente
- `scripts/agents-md-generate.sh` — generador
- `scripts/agents-md-drift-check.sh` — gate
