---
id: SPEC-114
title: Docs alignment post-SPEC-109/111/112/113
status: SUPERSEDED
superseded_by: SE-078
superseded_at: "2026-04-26"
origin: task #21 docs audit (2026-04-17)
author: Savia
---

# SPEC-114 — Docs Savia Alignment

> **SUPERSEDED 2026-04-26 by SE-078** — La automatización del docs-alignment para agentes
> queda absorbida por `AGENTS.md` (single source cross-frontend). Contenido conservado
> únicamente para audit. Ver `docs/propuestas/SE-078-agents-md-cross-frontend.md`.

## Why

Tras 7 PRs (SPEC-109 + SPEC-111 + SPEC-112/113) la documentación desalineaba:
- README multi-idioma con counts obsoletos (513/56/91 vs 532/64/76)
- Refs a skills borradas (coherence-check, predictive-analytics, visual-quality) en docs y agents
- SPEC-046 declarando dependencia de skill eliminada

## Scope

### 1. READMEs — 11 idiomas actualizados

Counts sincronizados a realidad post-merges:
- commands: 513 → 532
- agents: 56 → 64
- skills: 91 → 76

Ficheros: `README.md`, `README.en.md`, `README.pt.md`, `README.fr.md`, `README.gl.md`, `README.ca.md`, `README.de.md`, `README.eu.md`, `README.it.md`, `README.es.md` (y `.ja`, `.nl`, `.no`, `.ro`, `.sv`, `.zh` cuando aplican).

### 2. Refs stale a skills borradas

- `.opencode/CLAUDE.md:103`: `predictive-analytics` → `enterprise-analytics` (skill viva que absorbió funcionalidad Monte Carlo).
- `.claude/agents/coherence-validator.md:18`: skill `coherence-check` eliminada → `skills: []` (el agent sigue funcionando vía `/check-coherence` command).
- `docs/quick-starts/quick-start-qa.md:67` y `docs/quick-starts_en/quick-start-qa.md:67`: directorio `skills/coherence-check/` → referencia a `commands/check-coherence.md`.
- `docs/propuestas/SPEC-046-visual-diff-qa-merge.md:5`: dependencia `visual-quality skill` → `visual-qa command`.
- `.claude/commands/spec-verify-ui.md:131`: comentario "es coherence-check" → "es check-coherence".

## Implementation

Ediciones puntuales; no introduce código nuevo. Drift-check CI (SPEC-109 item 7) previene futuras regresiones automáticamente.

## Acceptance criteria

1. `grep -r "513\\|56 agent\\|91 skill" README*.md` devuelve cero.
2. `grep -r "coherence-check\\|predictive-analytics\\|visual-quality skill"` en `.opencode/`, `.claude/`, `docs/` devuelve cero (excepto CHANGELOG y docs/audits/).
3. `bash scripts/claude-md-drift-check.sh` pasa.

## Rejected

- Auto-generar READMEs desde script: mantenibilidad baja, diverge traducciones.
- Reescribir SPEC-046 completo: la spec sigue siendo válida, solo falla la dependencia nombrada.
