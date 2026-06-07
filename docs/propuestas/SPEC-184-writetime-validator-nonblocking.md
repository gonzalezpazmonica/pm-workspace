---
spec_id: SPEC-184
title: Write-time validator non-blocking (warn → self-repair same turn)
status: IMPLEMENTED
implemented_at: 2026-06-04
tier: 1
priority: P1
effort: 3-4h
era: 199
wave: 1
deps: []
unblocks: []
origin: output/research/obsidian-second-brain-mejoras-cupulas-20260601.md
inspiration: obsidian-second-brain `validate-ai-first.sh` PostToolUse hook (warn-non-blocking pattern)
timeline:
  - from: "2026-06-01"
    until: "2026-06-04"
    learned: "2026-06-01"
    value: "PROPOSED"
    source: "feat(roadmap): Era 199 -- 7 SPECs from obsidian-second-brain analysis (#794)"
  - from: "2026-06-04"
    learned: "2026-06-04"
    value: "IMPLEMENTED"
    source: "feat(spec-184): write-time non-blocking validators (#808)"
---

# SPEC-184 — Write-time validator non-blocking

> Estado: IMPLEMENTED · Tier 1 · P1 · Estimación 3-4h · Era 199 · Wave 1
>
> Implementación 2026-06-04. Hook .opencode/hooks/post-write-validate.sh +
> 4 validators (banned-unicode, frontmatter, spec-status,
> memory-entry-length). Tests 29/29, audit 91/100, latencia medida 23ms.

## Resumen

Hook PostToolUse que tras Write/Edit en ficheros markdown del workspace ejecuta validaciones rápidas (frontmatter, banned unicode, missing fields) y emite warnings a stderr SIN bloquear. El agente las ve en el mismo turno y auto-corrige. Evita el round-trip de commit-guardian (write→commit→fail→re-write).

## Motivación

- commit-guardian es bloqueante: el agente escribe, intenta commit, falla, lee error, re-escribe. 2-3 turnos perdidos.
- Patrón obsidian: warn al stderr post-write → mismo turno auto-corrige. 1 turno.
- Validaciones ligeras (regex, schema check) no necesitan ser bloqueantes.

## Scope

1. Hook `.opencode/hooks/post-write-validate.sh` registrado PostToolUse Write|Edit, filter `*.md`.
2. Validators componibles (cada uno script independiente, exit 0 always, stderr para warnings):
   - `validate-frontmatter.sh` — campos requeridos por tipo de doc.
   - `validate-banned-unicode.sh` — em-dash, curly quotes, NBSP, ellipsis (reporta codepoint + ASCII replacement).
   - `validate-spec-status.sh` — SPECs deben tener `status` enum válido.
   - `validate-memory-entry-length.sh` — entries MEMORY <150 chars.
3. Bypass dirs: `output/`, `.git/`, `node_modules/`, `dist/`, `raw/`.
4. Formato warning: `[WARN][validator-name][file:line] message + suggested fix`.
5. Toggle global: `SAVIA_WRITE_VALIDATORS_ENABLED=false` desactiva todo.

## Acceptance Criteria

- AC1: Hook SIEMPRE exit 0 (nunca bloquea — warn-only).
- AC2: Edit que introduce em-dash en un .md genera warning con codepoint U+2014 y sugerencia `--`.
- AC3: Crear SPEC nuevo sin `status:` genera warning frontmatter incompleto.
- AC4: Edit en `output/` no dispara validators (bypass).
- AC5: Setting `SAVIA_WRITE_VALIDATORS_ENABLED=false` silencia hook completo.
- AC6: BATS test con 4 fixtures (uno por validator) verifica warning correcto.
- AC7: Latencia hook <100ms p95 (medido con `hook-latency-gate`).
- AC8: Warning incluye sufficient context para que el agente auto-corrija sin necesitar re-leer el fichero.

## Slices

1. **Slice 1 (1h)** — Hook orchestrator + bypass dirs + toggle.
2. **Slice 2 (1.5h)** — 4 validators + BATS.
3. **Slice 3 (0.5-1h)** — Registro en `.claude/settings.json` + latency gate verification.
4. **Slice 4 (0.5h)** — Doc en `docs/rules/domain/write-time-validation.md`.

## Out of scope

- Validators bloqueantes (eso sigue siendo commit-guardian).
- Validación de código (solo markdown en v1).
- Auto-fix por el hook (solo warn — el agente decide).
- Validación cross-fichero (ej. checks de coherencia entre 2 specs).
