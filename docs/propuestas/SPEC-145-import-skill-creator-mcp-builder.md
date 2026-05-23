---
spec_id: SPEC-145
title: Importar anthropics/skill-creator y anthropics/mcp-builder como skills oficiales
status: IMPLEMENTED
origin: Investigación 2026-05-23 (P9). Anthropic mantiene skills oficiales (skill-creator, mcp-builder, webapp-testing) en https://github.com/anthropics/skills. Savia tiene `prompt-optimizer` pero no las herramientas oficiales para autoría rápida.
severity: Baja — acelera autoría interna, no resuelve gap crítico.
effort: ~3h (S) — clonado + verificación + integración.
priority: P9 — quality of life para el propio mantenimiento de Savia.
confidence: alta
bucket: Q2 2026
related_specs:
  - SPEC-141 (MCP catalog — mcp-builder ayuda a construir las plantillas)
  - SPEC-143 (SKILL.md conformance — skill-creator emite skills conformes por defecto)
---

# SPEC-145 — Import skill-creator + mcp-builder

## Why

Crear skills y MCP servers nuevos es un workflow que Savia ya hace pero sin tooling oficial. Anthropic publica y mantiene en `github.com/anthropics/skills`:

- `skill-creator` — interactivo, genera SKILL.md conforme a Agent Skills 1.0 (frontmatter limpio, body ≤500 líneas, subdirs `references/`).
- `mcp-builder` — scaffold para un MCP server stdio + Server Card + tests.
- `webapp-testing` — orchestrator para testing E2E de webapps con Playwright.

Importar las dos primeras (skill-creator + mcp-builder) acelera la autoría de las skills y plantillas MCP propuestas en SPEC-141 y SPEC-148, y nos mantiene en sync con upstream sin reinventar.

## Scope

### Funcional

1. **Clonar** subset de `github.com/anthropics/skills`:
   - `skills/skill-creator/SKILL.md` + recursos.
   - `skills/mcp-builder/SKILL.md` + recursos.
   - NO clonar `webapp-testing` (out of scope ahora).

2. **Adaptar mínimamente**:
   - Renombrar conflictos si hay (no se esperan, son lowercase-kebab).
   - Mantener attribution en frontmatter (`origin: anthropics/skills`, `license: Apache-2.0`).
   - Adaptar paths absolutos si el skill los referencia (ej. `~/.claude/...` → resolver via `savia-env.sh`).

3. **Validar conformidad** con SPEC-143: las skills oficiales deben pasar `audit-skill-md-spec.sh` (si Anthropic las mantiene, deberían cumplir).

4. **Documentar** en `docs/rules/domain/skill-authoring.md` el flujo:
   - "Para crear una skill nueva: invoca `skill-creator`"
   - "Para crear un MCP server: invoca `mcp-builder`"
   - Mantener la skill propia `prompt-optimizer` para casos avanzados.

5. **Watcher de actualización**: añadir `anthropics/skills` a la lista de SPEC-146 (awesome watcher mensual) para detectar updates.

### No funcional

- Sin red en runtime — clonado se hace una vez en la PR.
- Tamaño total <50KB.

## Design

### Estructura

```
.claude/skills/
├── skill-creator/
│   ├── SKILL.md         # importado, attribution preserved
│   └── references/      # recursos del skill
└── mcp-builder/
    ├── SKILL.md
    └── references/

.opencode/skills/        # mirror via symlink existente

docs/rules/domain/
└── skill-authoring.md   # nuevo, flujo canónico para autoría
```

## Acceptance Criteria

- [ ] AC-01: `.claude/skills/skill-creator/SKILL.md` y `mcp-builder/SKILL.md` presentes, attribution en frontmatter.
- [ ] AC-02: `audit-skill-md-spec.sh` (SPEC-143) pasa sobre ambos.
- [ ] AC-03: Smoke test: invocar skill-creator pidiendo "skill para X" produce SKILL.md válido en `output/`.
- [ ] AC-04: Smoke test: invocar mcp-builder pidiendo "MCP para listar PRs" produce server stdio + Server Card.
- [ ] AC-05: Doc `skill-authoring.md` explica cuándo usar skill-creator vs prompt-optimizer.
- [ ] AC-06: `anthropics/skills` añadido al watcher (SPEC-146).

## Implementation Note (2026-05-23)

**Decision**: vendored under `external/anthropic-skills/` instead of
`.claude/skills/`. Upstream SKILL.md files exceed Rule #11 (150-line cap):
`skill-creator/SKILL.md` is 485 lines by design. Importing them into
`.claude/skills/` would either violate Rule #11 or require structural
surgery that defeats the point of vendoring.

`external/` is a new top-level directory governed by `external/README.md`.
It is invisible to workspace auditors (agents catalog, skills index,
drift-check). Each package carries upstream LICENSE.txt verbatim plus a
`PROVENANCE.md` (SHA, date, URL).

**Imported**:
- `external/anthropic-skills/skill-creator/` (Apache-2.0)
- `external/anthropic-skills/mcp-builder/` (Apache-2.0)

**Tests**: `tests/test-anthropic-skills-import.bats` (8/8 PASS).

**Follow-up**: `scripts/anthropic-skills-sync.sh` for re-sync. Not shipped
in this slice; manual sync documented in `external/README.md`.

## Agent Assignment

- **Capa**: Infrastructure (tooling)
- **Agente**: `dev-orchestrator` (integración) + `tech-writer` (docs)

## Slicing

- **Slice 1** (1.5h) — Clonado y adaptación de skill-creator.
- **Slice 2** (1h) — Clonado y adaptación de mcp-builder.
- **Slice 3** (0.5h) — Doc + watcher entry.

## Feasibility Probe

Antes de Slice 2: verificar que skill-creator funciona end-to-end produciendo una skill válida. Si no, ajustar adaptación. Si requiere muchas modificaciones (>20% del contenido), abrir issue upstream + documentar deuda y NO importar mcp-builder (esperar arreglo upstream).

## Riesgos

- **License compatibility**: anthropics/skills es Apache-2.0 con permiso de incorporación. Savia es propio. Sin conflicto si mantenemos attribution. Verificar antes del Slice 1.
- **Drift upstream**: las skills cambian periódicamente. Mitigación — watcher mensual + política de actualizar trimestralmente.
- **Duplicación con `prompt-optimizer`**: prompt-optimizer es más AutoResearch oriented; skill-creator es estructura/conformance. No solapan. Doc lo deja claro.
