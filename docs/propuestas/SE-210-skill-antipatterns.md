---
spec_id: SE-210
title: Explicit anti-patterns section in critical skills
status: IMPLEMENTED
applied_at: "2026-06-24"
priority: P2
effort: M
era: 201
origin: output/research/mattpocock-skills-savia-20260607.md
inspiration: mattpocock/skills tdd anti-horizontal-slicing pattern
---

# SE-210 — Anti-patterns explícitos en skills críticas

## Problema

Las skills de mayor uso (tdd-vertical-slices, spec-driven-development, grill-me, zoom-out, caveman, savia-memory) describen el camino correcto pero no nombran los errores frecuentes. Un agente sin contexto previo puede:

- En `tdd-vertical-slices`: escribir todos los tests primero antes de implementar (horizontal slicing — ya documentado pero sin sección dedicada).
- En `spec-driven-development`: generar specs sin AC verificables, o saltarse la aprobación humana.
- En `grill-me`: aplicar crítica genérica en lugar de específica al artefacto concreto.
- En `zoom-out`: hacer zoom-out de todo en lugar de solo del componente en cuestión.
- En `caveman`: activar caveman en respuestas que el usuario ha pedido con detalle.
- En `savia-memory`: guardar datos sin categoría tipada o sin source de trazabilidad.

## Solución

Añadir sección `## Anti-patterns` en las 6 skills. Cada entrada nombra el error, explica por qué falla, y da la alternativa correcta. Formato visual comparable (antes/después implícito).

## Scope

### Skills a modificar (líneas actuales → margen disponible)

| Skill | Líneas actuales | Margen hasta 150 | Estrategia |
|---|---|---|---|
| `tdd-vertical-slices` | 125 | 25 | Inline en SKILL.md |
| `spec-driven-development` | 149 | 1 | Extraer a `REFERENCE.md` (AC4) |
| `grill-me` | 51 | 99 | Inline en SKILL.md |
| `zoom-out` | 56 | 94 | Inline en SKILL.md |
| `caveman` | 57 | 93 | Inline en SKILL.md |
| `savia-memory` | 81 | 69 | Inline en SKILL.md |

### Formato de cada sección

```markdown
## Anti-patterns

**❌ [Nombre del anti-pattern]**: [qué hace el agente mal] → [consecuencia].
**✓ Correcto**: [qué hacer en su lugar].
```

Máximo 10 líneas por sección, 1-3 anti-patterns por skill.

### Anti-patterns propuestos por skill

**tdd-vertical-slices** (1-2 anti-patterns, ~6 líneas):
- `Horizontal slicing`: escribir todos los tests antes de implementar → tests acoplados a implementación, fallos en cascada al refactorizar.
- `Slice demasiado grueso`: abarcar >1 comportamiento observable en un slice → fallo de red-green-refactor, no se puede aislar el error.

**spec-driven-development** (2 anti-patterns, ~8 líneas — en REFERENCE.md):
- `AC sin criterio verificable`: AC del tipo "el sistema debe ser rápido" → imposible automatizar la validación.
- `Merge sin aprobación humana`: el agente hace merge del PR de la spec → viola Rule #8 directamente.

**grill-me** (2 anti-patterns, ~7 líneas):
- `Crítica genérica`: listar defectos de cualquier código (naming, style) en lugar de los específicos del artefacto bajo revisión → ruido sin señal.
- `Activar en código no propuesto`: usar grill-me sobre código legacy no relacionado con el cambio → scope creep.

**zoom-out** (1 anti-pattern, ~4 líneas):
- `Zoom-out de todo el sistema`: revisar toda la arquitectura cuando la pregunta es sobre un componente concreto → respuesta demasiado abstracta para la decisión en curso.

**caveman** (1 anti-pattern, ~4 líneas):
- `Caveman cuando el usuario pide detalle explícito`: si el usuario dice "explícame" o "detalla", caveman no aplica — el usuario ya ha dado permiso para verbosidad necesaria.

**savia-memory** (2 anti-patterns, ~7 líneas):
- `Guardar sin tipo`: usar `--type custom` para todo en lugar del tipo semántico correcto (`decision`, `discovery`, `bug`, etc.) → memoria no recuperable por topic.
- `Guardar sin source`: omitir `--source skill:<name>` o `--source session` → trazabilidad rota, entries huérfanas.

## Acceptance Criteria

- **AC1**: Las 6 skills tienen sección `## Anti-patterns` con al menos 1 entrada cada una.
- **AC2**: Ninguna skill supera 150 líneas tras el cambio. `spec-driven-development` usa `REFERENCE.md` si la sección no cabe inline.
- **AC3**: Cada anti-pattern es específico al artefacto de la skill (no genérico) y nombra la consecuencia concreta.
- **AC4**: `spec-driven-development` extrae los anti-patterns a `.claude/skills/spec-driven-development/REFERENCE.md` con enlace desde SKILL.md si al añadirlos supera 150 líneas.

## Validación

```bash
# Verificar que las 6 skills tienen la sección
for skill in tdd-vertical-slices spec-driven-development grill-me zoom-out caveman savia-memory; do
  grep -l "## Anti-patterns" .claude/skills/$skill/SKILL.md .claude/skills/$skill/REFERENCE.md 2>/dev/null \
    || echo "MISSING: $skill"
done

# Verificar que ninguna supera 150 líneas
for skill in tdd-vertical-slices grill-me zoom-out caveman savia-memory; do
  lines=$(wc -l < .claude/skills/$skill/SKILL.md)
  [ "$lines" -ge 150 ] && echo "FAIL: $skill has $lines lines"
done
```

## OpenCode Implementation Plan

```yaml
classification: PURE_BASH
files_touched:
  - .claude/skills/tdd-vertical-slices/SKILL.md
  - .claude/skills/spec-driven-development/SKILL.md  # o REFERENCE.md
  - .claude/skills/grill-me/SKILL.md
  - .claude/skills/zoom-out/SKILL.md
  - .claude/skills/caveman/SKILL.md
  - .claude/skills/savia-memory/SKILL.md
requires_restart: false
verification: |
  for s in tdd-vertical-slices grill-me zoom-out caveman savia-memory; do
    grep -q "## Anti-patterns" .claude/skills/$s/SKILL.md || exit 1
  done
```

## Referencias

- `docs/propuestas/SE-208-skill-100-line-limit.md` — límite 100 líneas y satélites
- `docs/rules/domain/skill-template-protocol.md` — protocolo template
- `docs/ROADMAP.md#era-201` — Era 201 Skill quality discipline
