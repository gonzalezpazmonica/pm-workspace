---
id: SE-078
title: SE-078 — AGENTS.md adoption — single source para Claude Code + OpenCode + Codex
status: IMPLEMENTED
origin: Strategic decision 2026-04-26 — vendor-lockin mitigation
author: Savia
priority: alta
effort: M 6h — IMPLEMENTED 2026-04-26
related: SE-077, SPEC-114
approved_at: "2026-04-26"
applied_at: "2026-04-26"
expires: "2026-06-26"
era: 189
---

# SE-078 — AGENTS.md cross-frontend single source

## Why

Hoy Savia define 65 agentes en `.claude/agents/*.md` con frontmatter Anthropic-specific. OpenCode v1.14, Codex, Cursor y otros frontends modernos leen un formato emergente común: **`AGENTS.md`** (existe SPEC-114 PROPOSED al respecto, sin acción).

Sin single source, la deuda crece linealmente: cada nuevo agente requiere mantenerlo en N formatos, o quedar Claude-Code-only. Esto **mata SE-077 en la práctica**: aunque OpenCode esté operativo, los agentes que escribimos hoy no funcionarán allí salvo que se mantengan ambos formatos.

Cost of inaction: vendor lock-in via formato propietario, aunque la infra (SE-077) sea portable.

## Scope (Slice único, M 6h)

1. **Generador**: `scripts/agents-md-generate.sh`
   - Input: `.claude/agents/*.md` (65 agentes actuales)
   - Output: `AGENTS.md` en repo root (uno por proyecto que tenga agentes propios)
   - Formato: tabla canonical AGENTS.md ([spec emergente](https://agents.md))
   - Idempotente: re-run produce mismo hash si no hay cambios

2. **Validator**: `scripts/agents-md-drift-check.sh`
   - Compara AGENTS.md vs `.claude/agents/*.md`
   - Falla si hay agente nuevo sin entrada AGENTS.md
   - Integra en pr-plan G_AGENTS_MD (nuevo gate)

3. **Hook Stop**: `agents-md-auto-regenerate.sh` async — si la sesión añadió/modificó `.claude/agents/*.md`, regenera AGENTS.md y muestra diff

4. **Migration**: ejecutar generador 1 vez, commit AGENTS.md inicial, verificar que OpenCode lo lee correctamente

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Definición de agentes | `.claude/agents/*.md` (autoritativo) | Lee `AGENTS.md` desde repo root + `.opencode/agents/` (fallback) |
| Generación | Manual (humano edita .claude/agents/*.md) | Auto-derivada de AGENTS.md mediante symlink o regenerator |
| Drift detection | `agents-catalog-sync.sh` (existe, SPEC-047) | `agents-md-drift-check.sh` (nuevo) |

### Verification protocol

- [ ] AGENTS.md generado contiene 65 entries (matches `.claude/agents/`)
- [ ] OpenCode v1.14 carga agentes desde AGENTS.md sin error
- [ ] Drift check detecta agente nuevo en `.claude/agents/` no propagado a AGENTS.md (test: añadir dummy, verificar fail)
- [ ] Stop hook regenera AGENTS.md tras edición de un agente

### Portability classification

- **DUAL_BINDING**: AGENTS.md es la single source. Claude Code lee `.claude/agents/*.md` (formato origen) — convención mantenida. OpenCode lee AGENTS.md (formato derivado).

## Acceptance criteria

- [x] AC-01 `scripts/agents-md-generate.sh` produce AGENTS.md válido con todos los agentes
- [x] AC-02 AGENTS.md commiteado en repo root
- [x] AC-03 `scripts/agents-md-drift-check.sh` detecta drift agente-nuevo (8 tests, score 81)
- [x] AC-04 Hook Stop async `agents-md-auto-regenerate.sh` registrado en `settings.json`
- [ ] AC-05 OpenCode v1.14 carga sin error — **pendiente de boot por la usuaria**
- [x] AC-06 Tests BATS: 22 generate (score 88) + 8 drift (score 81) = 30 tests
- [x] AC-07 Doc `docs/rules/domain/agents-md-source-of-truth.md`
- [x] AC-08 SPEC-114 marcada SUPERSEDED-by SE-078 (frontmatter + banner)
- [x] AC-09 CHANGELOG entry

## No hacen

- NO sustituye `.claude/agents/*.md` como fuente original — esos siguen siendo donde se editan los agentes
- NO migra el formato Anthropic-specific a otro estándar — solo añade espejo AGENTS.md derivado
- NO toca skills (skills tienen su propio mecanismo; SE-078 only aborda agents)
- NO requiere cambios en agentes individuales

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Spec AGENTS.md cambia entre frontends | Media | Medio | Generador parametrizable; pinear schema en script |
| Drift detection demasiado estricto rompe CI | Baja | Bajo | Audit ratchet pattern (igual que hook coverage) |
| OpenCode no encuentra AGENTS.md | Baja | Alto | Verificación E2E en AC-05; fallback a `.opencode/agents/` symlink |
| AGENTS.md crece muy grande (65 agentes) | Media | Bajo | Ya tenemos rate-limit de tokens; AGENTS.md formato compacto |

## Dependencias

- **No bloquea por**: nada
- **Bloquea SE-077 Slice 2** (parity audit completo necesita AGENTS.md como referencia)
- **Independiente de**: SE-073, SE-074, SE-075, SE-076

## Referencias

- `https://agents.md/` — spec emergente
- SPEC-114 docs-savia-alignment (PROPOSED, será SUPERSEDED por SE-078)
- SE-077 OpenCode replatform (sinergia: SE-078 entrega los agentes a OpenCode runtime)
- `scripts/agents-catalog-sync.sh` — patrón existente de auto-sync (modelo para drift check)
- Decisión estratégica de la usuaria 2026-04-26
