# Spec OpenCode Implementation Plan — Rule

> Cada spec APPROVED desde 2026-04-26 incluye sección obligatoria documentando cómo se implementa en OpenCode además de Claude Code. Sin esta sección no es soberanía técnica, es deuda con vendor lock-in.

## Por qué

Anthropic está restringiendo Claude Code (Pro → Max-only abril 2026). Si los nuevos specs solo se piensan en Claude Code, el día que Anthropic apriete tornillos Savia se queda sin frontend operativo. Esta regla garantiza que cada decisión de implementación contemple ambos motores desde el origen — no como retrofit posterior.

La regla es prospectiva: solo aplica a specs APPROVED post-2026-04-26. Specs anteriores son grandfathered (su retrofit es trabajo separado, ej. SE-077).

## Sección obligatoria

Cada spec APPROVED debe incluir:

```markdown
## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| <hook X> | `.opencode/hooks/X.sh` registered in settings.json | Plugin TS function `<hook_event>` |
| <agent X> | `.opencode/agents/X.md` | Lee desde AGENTS.md generado |
| <skill X> | `.opencode/skills/X/SKILL.md` | Skill registry |
| ... | ... | ... |

### Verification protocol

- [ ] Funciona en runtime OpenCode (no solo Claude Code)
- [ ] Tests cubren ambos paths (o marca SKIP justificado)
- [ ] Si añade hooks: registrados en plugin `savia-gates`

### Portability classification

(elige UNA, justifica si es la última)

- [ ] **PURE_BASH**: lógica en bash sin bindings de frontend, runs idéntico en cualquier motor
- [ ] **DUAL_BINDING**: implementado para Claude Code Y OpenCode desde Slice 1
- [ ] **SINGLE_BINDING_DEFERRED**: implementado en uno, port pendiente en spec/batch específico (citar)
- [ ] **CLAUDE_CODE_ONLY**: justificación obligatoria — feature que OpenCode no soporta upstream y workaround es inviable. Requiere aprobación explícita de la usuaria.
```

## Enforcement

### Audit script

`scripts/spec-opencode-plan-audit.sh`:

- Escanea `docs/propuestas/SE-*.md` y `docs/propuestas/SPEC-*.md`
- Filtra `status: APPROVED` o `status: IMPLEMENTED` con `approved_at >= 2026-04-26`
- Verifica presencia de heading `## OpenCode Implementation Plan`
- Verifica que tiene al menos las 3 sub-secciones (Bindings, Verification, Portability)
- Reporta specs missing
- Exit code 0 si todos compliant, 1 si hay missing

### Gate en pr-plan

Nuevo gate `G12 spec-opencode-plan`:
- Si el PR añade/modifica un spec APPROVED post-cutoff
- Verifica sección presente y bien formada
- Falla si missing — mensaje didáctico con link a esta regla

### Baseline

`.ci-baseline/spec-opencode-plan-violations.count` con número actual congelado (debe ser 0 al introducir la regla).

## Excepciones

### Grandfathering

Specs APPROVED antes de 2026-04-26 NO requieren la sección. Lista grandfathered en `docs/grandfathered-specs-pre-opencode-rule.md` (auto-generada en el batch que introduce la regla).

### Hot-fix exemption

Specs marcados `priority: critical` y `applied_at` mismo día que `approved_at` (urgencia operativa real) pueden saltarse la regla con `exempt_opencode_plan: <razón>` en frontmatter. Audit ratchet detecta y reporta sin bloquear.

### CLAUDE_CODE_ONLY

Selección legítima cuando:
- Feature de Claude Code sin equivalente en OpenCode (ej. Subagent fan-out — issue #12661 abierto upstream)
- Workaround introduce más complejidad que valor
- La usuaria aprueba explícitamente el lock-in para este spec

NO es excepción válida:
- "No tengo tiempo ahora" → usar SINGLE_BINDING_DEFERRED y commitear el follow-up
- "OpenCode no es prioridad" → la regla EXISTE precisamente porque OpenCode SÍ es prioridad estratégica

## Ejemplos cortos

**PURE_BASH**: `Bindings: N/A (solo scripts bash + BATS)`. **Verification**: tests pasan bash 5.x. **Classification**: PURE_BASH.

**DUAL_BINDING**: tabla con hook → plugin function, skill → symlink. **Verification**: tests Claude Code + tests E2E OpenCode. **Classification**: DUAL_BINDING.

**CLAUDE_CODE_ONLY**: justificar (ej. Subagent fan-out, issue #12661 upstream sin fecha). **Aprobación de la usuaria** obligatoria con cita.

## Política de evolución

Esta regla se revisa cuando:
- OpenCode publique v2 (esperado Q3 2026) — replantear bindings table
- Anthropic relaje restricciones de Claude Code → opcional pero NO se quita la regla (la portabilidad no caduca)
- Aparezca un 3er frontend relevante (Cursor, Codex, futuros) — extender bindings table sin romper la regla

## Referencias

- SE-077 OpenCode v1.14 replatform — el spec que materializa los bindings
- SE-078 AGENTS.md adoption — single source para agentes cross-frontend
- `scripts/spec-opencode-plan-audit.sh` — enforcement
- `docs/rules/domain/pr-natural-language-summary.md` — patrón de regla similar (sección obligatoria + audit)
- `https://github.com/sst/opencode` — frontend objetivo
- Decisión estratégica de la usuaria 2026-04-26
