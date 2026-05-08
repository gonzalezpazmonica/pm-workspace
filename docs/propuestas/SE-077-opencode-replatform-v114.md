---
id: SE-077
title: SE-077 — OpenCode v1.14 replatform — sovereignty bridge
status: IMPLEMENTED
origin: Strategic decision 2026-04-26 — vendor-lockin mitigation
author: Savia
priority: alta
effort: M 8h (Slice 1) + M 6h (Slice 2) — IMPLEMENTED 2026-04-26 (E2E pendiente de boot por la usuaria)
related: SE-078, SE-055 (supersedes), SPEC-122, sovereignty-switch
approved_at: "2026-04-26"
applied_at: "2026-04-26"
expires: "2026-06-26"
era: 189
---

# SE-077 — OpenCode v1.14 replatform

## Why

Anthropic está restringiendo Claude Code: Pro → Max-only en abril 2026. Trayectoria sugiere API-only en 6-18 meses. El consumo actual de Savia (60 hooks × 86 skills × ratchet pattern + drift audits) a precios API es **inasumible** sin subscripción Max.

La adopción actual de OpenCode en Savia (v1.3.13, instalado pero no usado, wrappers `safe-*.sh`, SE-055 priority baja vencido) es **deuda obsoleta**: OpenCode v1.14.x ya tiene hooks nativos, plugin SDK TS, worktree, permission system con SQLite. Los wrappers de bash que escribimos para v1.3 son arquitecturalmente innecesarios.

Cost of inaction: el día que Anthropic apriete, Savia no puede operar. La ventana actual (mientras Max funciona) es la única oportunidad para construir el puente.

**Esta no es una migración total**: Claude Max sigue siendo el frontend principal. OpenCode es el **plan B operativo** que tiene que estar testeado y vivo, no en un cajón.

## Scope

### Slice 1 (M, 8h) — Compat layer activo

1. **Upgrade**: instalar OpenCode v1.14.25 (current) en `~/.savia/opencode/`. Pinear versión.
2. **Plugin TS**: `~/.savia/opencode/plugins/savia-gates/` con:
   - `tool.execute.before` registra los hooks bash existentes (block-credential-leak, block-force-push, etc.) como gates
   - `permission.ask` integra AUTONOMOUS_REVIEWER policy
   - `chat.message` ejecuta UserPromptSubmit hooks (memory-prime, etc.)
3. **Symlinks**: `.opencode/` apunta a `.claude/` para que skills/agents se compartan (esto ya existe parcialmente)
4. **Retire wrappers**: marcar `scripts/opencode-hooks/wrappers/safe-*.sh` como deprecated, conservar 1 sprint, eliminar
5. **Test E2E**: ejecutar 1 batch real de Savia (ej. SE-073 Memory Index Cap Tiered) en OpenCode end-to-end. Verifica: pr-plan local funciona, hooks disparan, AUTONOMOUS_REVIEWER respetado.

### Slice 2 (M, 6h) — Parity baseline + ratchet

1. Script `scripts/opencode-parity-audit.sh`: para cada hook bash en `.opencode/hooks/`, verifica que existe equivalente registrado en plugin TS o que esté justificado como Claude-Code-only en frontmatter
2. Baseline `.ci-baseline/opencode-parity-gap.count` con violaciones documentadas
3. Test mensual: bash `scripts/opencode-monthly-canary.sh` ejecuta tarea representativa en OpenCode + Claude Code y compara outputs (no quality, sólo equivalence — ¿completa los gates? ¿genera pr-plan green?)

## OpenCode Implementation Plan

(Esta sección es self-aplicada — SE-077 es exactamente el spec que define cómo hacer OpenCode-portable cualquier spec.)

### Bindings touched (Claude Code → OpenCode equivalents)

| Claude Code | OpenCode v1.14 |
|---|---|
| `.opencode/hooks/PreToolUse/*.sh` registered in `settings.json` | Plugin TS function `tool.execute.before` |
| `.opencode/hooks/PostToolUse/*.sh` | `tool.execute.after` |
| `.opencode/hooks/SessionStart/*.sh` | **Not exposed natively** — workaround: invoke from CLI wrapper or `experimental.session.compacting` for partial coverage |
| `.opencode/hooks/UserPromptSubmit/*.sh` | `chat.message` |
| `.opencode/agents/*.md` (subagents via Task tool) | `agent/` module + Agent Client Protocol; format sufficiently similar to share via AGENTS.md (SE-078) |
| `.opencode/skills/*/SKILL.md` | Skill registry (`Skill.Discovery.pull`); concurrency-bounded same |
| `.opencode/commands/*.md` (slash commands) | `command/` module + `command.execute.before` hook |

### Verification protocol

- [ ] Plugin TS plugin loads without error
- [ ] Hook coverage equivalent: ≥90% of Claude Code hooks have OpenCode binding (10% gap acceptable for SessionStart-class hooks not exposed upstream)
- [ ] pr-plan local executes green on OpenCode runtime
- [ ] AUTONOMOUS_REVIEWER policy enforced on OpenCode (test: agent attempts auto-merge → blocked)

### Portability classification

- **DUAL_BINDING**: this spec creates the dual binding for the entire workspace. After Slice 1, Savia operates on either frontend.

## Acceptance criteria

### Slice 1
- [x] AC-01 OpenCode v1.14.25 install scripted (`scripts/opencode-install.sh`); ejecución por la usuaria
- [x] AC-02 Plugin `savia-gates` registra 7 handlers (cubre ≥10 hooks críticos vía settings.json fan-out)
- [ ] AC-03 Test E2E: SE-073 ejecutable en OpenCode hasta pr-plan green — **pendiente de boot por la usuaria**
- [x] AC-04 AUTONOMOUS_REVIEWER respetado vía `permission.ask` deny en agent/* + destructive ops
- [x] AC-05 `scripts/opencode-hooks/wrappers/safe-*.sh` deprecation notice añadida
- [x] AC-06 Doc en `docs/rules/domain/opencode-savia-bridge.md`
- [x] AC-07 Tests BATS ≥18: 22 tests plugin (score 86) + 22 generador (score 88) + 8 drift (81)
- [x] AC-08 CHANGELOG entry

### Slice 2
- [x] AC-09 `scripts/opencode-parity-audit.sh` reporta gap (16 tests, score 85)
- [x] AC-10 Baseline `.ci-baseline/opencode-parity-gap.count` commiteado (re-baseline post-install)
- [ ] AC-11 Wrappers `safe-*.sh` eliminados — **pendiente tras 1 sprint de canary verde**
- [x] AC-12 Canary `scripts/opencode-monthly-canary.sh` implementado (16 tests, score 83)
- [x] AC-13 Tests BATS ≥10: 16 + 16 = 32 tests entre parity y canary

## No hacen

- NO migra el operativo principal a OpenCode — Claude Max sigue siendo frontend default
- NO sustituye SPEC-122 LocalAI emergency-mode (caso "API down" sigue cubierto independiente)
- NO promete paridad 100% — algunos hooks Claude Code-only quedan justificados
- NO toca local model adoption (eso es Era 190+ si Anthropic aprieta)
- NO añade GPU dependency

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| OpenCode v1.14 cambia API plugin antes de Slice 2 | Alta | Medio | Pin commit hash, no usar `latest` |
| Hook coverage gap mayor que 10% | Media | Medio | Documentar gaps, no bloquear merge si es minoría |
| Memory leaks en OpenCode (issue #20695 abierto) | Media | Bajo | Canary mensual detecta; restart workaround |
| Plugin TS introduce nueva dependencia (Bun) | Alta | Bajo | Bun ya runtime de OpenCode; no nueva dep |
| AUTONOMOUS_REVIEWER no replicable en plugin SDK | Baja | Alto | Investigado en research: `permission.ask` hook permite custom logic, viable |
| Slice 2 canary demasiado caro | Baja | Bajo | Tarea representativa pequeña (1 spec sin hardware) |

## Dependencias

- **Bloquea**: ninguna (entrada en cola Era 189 sin pre-requisitos)
- **Habilita**: SE-078 AGENTS.md (single source agentes para ambos frontends), futuras Eras de soberanía
- **Sinergia**: SPEC-122 emergency-mode puede extenderse para incluir trigger "vendor restriction" además de "API down"

## Referencias

- `https://github.com/sst/opencode` v1.14.25 (2026-04-25)
- `https://github.com/sst/opencode/tree/dev/packages/plugin/src` — Plugin SDK
- `https://github.com/sst/opencode/issues/20695` — Memory perf
- `https://github.com/sst/opencode/issues/12661` — Agent teams gap (Savia ahead aquí)
- SE-055 (PROPOSED priority baja, supersedes — marcar ARCHIVED post Slice 1)
- SPEC-122 LocalAI emergency-mode
- `scripts/sovereignty-switch.sh` — switchover Claude/OpenCode existente
- Decisión estratégica de la usuaria 2026-04-26: "compatibilizar al máximo OpenCode con Claude Max, regla que obligue plan OpenCode en cada spec"
