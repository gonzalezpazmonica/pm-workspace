---
spec_id: SE-215
title: Eval-driven skill improvement loop
status: IMPLEMENTED
drift_note: "drift: components existed pre-triage (scripts/eval-improvement-suggest.sh Slice1 + SAVIA_EVAL_AUTO_SUGGEST hook in run-agent-evals.sh Slice3; Slice2 eval-driven mode in code-improvement-loop partial)"
implemented_at: "2026-06-24"
priority: P1
effort: M
era: 203
origin: output/research/deepagents-savia-20260607.md
inspiration: langchain-ai/deepagents better-harness pattern (24k stars)
deps:
  - SE-204 (eval harness — implemented)
  - code-improvement-loop skill (implemented)
---

# SE-215 — Eval-driven skill improvement loop

## Problema

SE-204 tiene 9 eval cases para 3 agentes críticos. Los evals corren con `run-agent-evals.sh` y producen un reporte. Pero ahí termina el ciclo. El code-improvement-loop skill existe para mejorar código autónomamente. Los dos artefactos no están conectados: los evals no generan propuestas de mejora automáticas.

## Solución (3 slices)

### Slice 1 (~2h): `scripts/eval-improvement-suggest.sh`

- Lee `output/eval-report-{date}.md` (salida de run-agent-evals.sh)
- Para cada eval case que falla (score < threshold): genera una propuesta concreta de mejora en `output/eval-improvement-proposals-{date}.md`
- Formato de propuesta: `{skill_or_agent, eval_case, current_score, improvement_suggestion, files_to_modify[]}`
- `--dry-run`: imprime sin crear ficheros
- `--since <date>`: solo evalúa reports desde esa fecha

### Slice 2 (~3h): Integración con code-improvement-loop

- Añadir a `.opencode/skills/code-improvement-loop/SKILL.md` una sección `## Eval-driven mode`
- Cuando se activa con `--eval-driven`: lee las propuestas de Slice 1 y ejecuta mejoras en las skills/agentes señalados
- Crea PRs Draft por cada mejora (máx 3/sesión, respetando el límite existente)
- El PR incluye el eval case fallido + la propuesta + el cambio propuesto

### Slice 3 (~2h): Hook post-eval

- Añadir al final de `scripts/run-agent-evals.sh`: si score global < 80%, invocar automáticamente `eval-improvement-suggest.sh`
- Configurable via `SAVIA_EVAL_AUTO_SUGGEST=true` (default false)
- Output siempre en `output/` — nunca modifica skills directamente

## Acceptance Criteria

- **AC1**: `eval-improvement-suggest.sh` lee un eval report y genera propuestas JSON/markdown
- **AC2**: `--dry-run` no crea ficheros
- **AC3**: propuestas referencian el eval case específico que falló
- **AC4**: code-improvement-loop SKILL.md documenta el modo eval-driven
- **AC5**: `run-agent-evals.sh` con `SAVIA_EVAL_AUTO_SUGGEST=true` invoca el suggest script
- **AC6**: ningún script modifica skills directamente — solo propone (autonomous-safety Rule)

## Slices estimación

1. Slice 1 (2h): eval-improvement-suggest.sh
2. Slice 2 (3h): integración code-improvement-loop
3. Slice 3 (2h): hook post-eval

## OpenCode Implementation Plan

```yaml
classification: PURE_BASH
files_touched:
  - scripts/eval-improvement-suggest.sh  (new)
  - scripts/run-agent-evals.sh           (hook post-eval)
  - .opencode/skills/code-improvement-loop/SKILL.md  (eval-driven section)
requires_restart: false
verification: bash scripts/eval-improvement-suggest.sh --dry-run
```

## Referencias

- `scripts/run-agent-evals.sh` — eval harness SE-204
- `.opencode/skills/code-improvement-loop/SKILL.md` — skill existente
- `docs/rules/domain/autonomous-safety.md` — Rule AC6 (proponer, no ejecutar)
- `output/research/deepagents-savia-20260607.md` — origen del patrón
