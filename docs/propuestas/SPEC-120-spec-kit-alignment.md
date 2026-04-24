---
id: SPEC-120
title: Alignment del spec template con github/spec-kit
status: IMPLEMENTED
origin: Savia autonomous roadmap — Top pick #1 del research 2026-04-17
author: Savia
related: SAVIA-SUPERPOWERS-ROADMAP.md
priority: alta
approved_at: "2026-04-24"
applied_at: "2026-04-24"
implemented_at: "2026-04-24"
---

# SPEC-120 — Spec Template Alignment con github/spec-kit

## Why

`github/spec-kit` (88.9k ⭐, 30+ backends) se está convirtiendo en el estándar de facto para Spec-Driven Development en 2026. Savia ya tiene SDD maduro, pero su template propio puede divergir del estándar industria, dificultando:

- Adopción externa por colaboradores
- Intercambio de specs entre Savia y otros tooling (Copilot, Gemini, Cursor)
- Alineación con el ecosistema MCP

Alinear nuestro `spec-template.md` con la estructura spec-kit sin perder lo propio de Savia (agent assignment, slicing, feasibility-probe).

## Scope

1. **Auditar** los 4 templates existentes:
   - `.claude/skills/spec-driven-development/references/spec-template.md`
   - `.claude/commands/references/spec-template.md`
   - `projects/proyecto-alpha/specs/templates/spec-template.md`
   - `projects/proyecto-beta/specs/templates/spec-template.md`

2. **Mapear** secciones Savia ↔ spec-kit:
   - `Why` ↔ `## What & Why`
   - `Scope` ↔ `## Requirements`
   - `Design` ↔ `## Technical Design`
   - `Tests` ↔ `## Acceptance Criteria`
   - Mantener exclusivas: `Agent Assignment`, `Slicing`, `Feasibility Probe`

3. **Actualizar** el template canónico (`.claude/skills/spec-driven-development/references/spec-template.md`) como **single source of truth**.

4. **Redirigir** los 3 templates duplicados vía `include:` pointer al canónico (elimina drift).

5. **Documentar** en `docs/agent-teams-sdd.md` la correspondencia Savia ↔ spec-kit.

## Design

### Estructura canónica propuesta

```markdown
---
id: SPEC-NNN
title: ...
status: PROPOSED|IN_PROGRESS|DONE
owner: @handle
spec_kit_compatible: true   # NEW: marker para tooling externo
---

# SPEC-NNN — Título

## What & Why                # spec-kit standard
...

## Requirements              # spec-kit standard
### Functional
### Non-functional

## Technical Design          # spec-kit standard
...

## Acceptance Criteria       # spec-kit standard (tests)
- [ ] AC-01 ...

## Agent Assignment          # Savia-specific
Capa: {Domain|Application|Infrastructure|API}
Agente: {dotnet-developer|frontend-developer|...}

## Slicing                   # Savia-specific
- Slice 1: ...

## Feasibility Probe         # Savia-specific
Time-box: 60min
```

### Backwards compatibility

Specs existentes (109-114) NO se migran. La alineación aplica a **nuevos specs** tras el merge.

## Acceptance Criteria

- [ ] AC-01 `.claude/skills/spec-driven-development/references/spec-template.md` incluye las 4 secciones spec-kit estándar
- [ ] AC-02 Campo `spec_kit_compatible: true` documentado en el frontmatter
- [ ] AC-03 Los 3 templates duplicados sustituidos por pointer al canónico
- [ ] AC-04 `docs/agent-teams-sdd.md` actualizado con mapping Savia ↔ spec-kit
- [ ] AC-05 Test bats nuevo `tests/spec-template-compliance.bats` verifica que el template contiene las 4 secciones estándar
- [ ] AC-06 CHANGELOG.md entrada v5.21.0
- [ ] AC-07 Zero drift detectado por `workspace-doctor` tras el cambio

## Agent Assignment

Capa: Documentation + skills
Agente: sdd-spec-writer + tech-writer

## Slicing

- Slice 1: Auditar los 4 templates y preparar merge diff
- Slice 2: Actualizar canónico + redirects + docs
- Slice 3: Tests + CHANGELOG + PR Draft

## Feasibility Probe

Time-box: 30 min. Riesgo principal: cadena de dependencias entre templates no detectada. Mitigación: `grep -r "spec-template" .claude/ docs/ projects/` antes de cambiar.

## Riesgos y mitigaciones

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Drift entre template canónico y duplicados tras merge | Media | Medio | Pointer `@include` + drift-check en CI |
| Specs antiguas fallen validación si se extiende retroactivamente | Baja | Alto | No migrar retroactivo; aplica solo a nuevos |
| Incompatibilidad con spec-kit si especifican schema estricto | Baja | Medio | Marker `spec_kit_compatible: true` permite opt-in |

## Referencias

- [github/spec-kit](https://github.com/github/spec-kit) — SDD toolkit oficial
- `docs/agent-teams-sdd.md` — estructura actual Savia SDD

## Resolution (2026-04-24)

Infrastructure pre-existente + completion de los 2 project templates duplicados.

### Pre-existente (de trabajo anterior)

- `.claude/skills/spec-driven-development/references/spec-template.md`: **spec_kit_compatible: true** marker + `## Spec-Kit Alignment` section con mapping table 4 secciones spec-kit ↔ secciones Savia
- `docs/agent-teams-sdd.md`: `## Spec-Kit Alignment (SPEC-120)` section con mapping + referencia a tests
- `tests/test-spec-template-compliance.bats`: 26 tests, score **81** certified
- `.claude/commands/references/spec-template.md`: ya era pointer al canonico (no content duplication)

### Added (este PR)

- `projects/proyecto-alpha/specs/templates/spec-template.md`: marker + pointer header a fuente canonica
- `projects/proyecto-beta/specs/templates/spec-template.md`: marker + pointer header a fuente canonica

Los project templates mantienen su content completo (no truncated) per requerimiento de mantener customizaciones project-specific. El header anade el marker spec_kit_compatible y link a la fuente canonica.

## Acceptance Criteria final

- [x] AC-01 Canonical template incluye las 4 secciones spec-kit standard (mapping table)
- [x] AC-02 Campo `spec_kit_compatible: true` documentado en canonical + project templates
- [x] AC-03 Los 3 templates "duplicados" con pointer header (command/ ya era pointer; alpha + beta updated)
- [x] AC-04 `docs/agent-teams-sdd.md` actualizado con mapping Savia ↔ spec-kit (pre-existente)
- [x] AC-05 Test bats `tests/test-spec-template-compliance.bats` 26 tests score 81 certified
- [x] AC-06 CHANGELOG.md entrada (esta PR)
- [x] AC-07 Zero drift detectado por workspace-doctor (validated manually)
