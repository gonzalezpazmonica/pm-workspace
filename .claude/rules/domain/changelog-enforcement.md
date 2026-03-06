---
name: Changelog Enforcement
description: Fuerza la actualización de CHANGELOG.md con cada nueva versión y PR de feature
globs: ["CHANGELOG.md", ".claude/commands/*.md", ".claude/skills/*/SKILL.md", ".claude/rules/domain/*.md"]
context_cost: low
---

# Regla: Actualización obligatoria de CHANGELOG.md

## Cuándo aplica

SIEMPRE que se cumpla CUALQUIERA de estas condiciones:
1. Se crea una nueva versión (tag `vX.Y.Z`)
2. Se crea un PR con cambios en `commands/`, `skills/`, `rules/`, `agents/`, `hooks/`, `scripts/`
3. Se añade, modifica o elimina un comando, skill, regla, agente o hook
4. Se corrige un bug documentable

## Qué debe incluir la entrada

Seguir formato [Keep a Changelog](https://keepachangelog.com/en/1.0.0/):

```markdown
## [X.Y.Z] — YYYY-MM-DD

Descripción breve (1 línea) del cambio principal.

### Added / Changed / Fixed / Removed
- **Elemento**: descripción del cambio
```

### Campos obligatorios
- **Versión y fecha** en formato `[X.Y.Z] — YYYY-MM-DD`
- **Descripción** de una línea tras el heading
- **Sección(es)** Added/Changed/Fixed/Removed con bullets descriptivos
- **Contadores actualizados** si cambian: Commands count, Skills count, Hooks count
- **Link de comparación** al final del fichero: `[X.Y.Z]: URL/compare/vAnterior...vX.Y.Z`

### Versionado semántico
- **MAJOR** (X): cambios que rompen compatibilidad (nunca usado hasta ahora)
- **MINOR** (Y): nuevos comandos, skills, features
- **PATCH** (Z): fixes, calibraciones, mejoras menores

## Verificación pre-commit

Antes de crear un commit que incluya tag de versión:
1. Verificar que CHANGELOG.md tiene entrada para la nueva versión
2. Verificar que la fecha es correcta (ISO 8601)
3. Verificar que los contadores reflejan el estado real
4. **CRITICAL — Verificar que el link de comparación existe al final del fichero**

### ⚠️ STOP — Error recurrente: link de comparación olvidado

**BLOQUEANTE**: NO hacer commit de CHANGELOG.md sin completar estos 2 pasos:
1. Añadir heading `## [X.Y.Z] — YYYY-MM-DD` al principio del fichero
2. Añadir link `[X.Y.Z]: https://github.com/.../compare/vAnterior...vX.Y.Z` al bloque de links

El bloque de links está tras la última entrada (buscar `]: https://github.com`). Sin el link, el heading `## [X.Y.Z]` renderiza como texto plano sin enlace clicable.

**Verificación**: ejecutar `grep '^\[' CHANGELOG.md | head -5` para confirmar que la nueva versión aparece.

## Consecuencia de no cumplir

Si se detecta un PR mergeado sin entrada en CHANGELOG:
- Crear entrada retroactiva en el siguiente commit
- Incluir nota: "Retroactive changelog entry for PR #N"
