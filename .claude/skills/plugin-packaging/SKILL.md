---
name: plugin-packaging
description: Empaquetar y validar PM-Workspace como plugin distributable
maturity: stable
dependencies: ["context-optimized-dev"]
context_cost: low
category: "devops"
tags: ["plugin", "packaging", "distribution", "manifest"]
priority: "low"
---

# Skill: Plugin Packaging

Lógica para empaquetar pm-workspace como plugin distributable para Claude Code.
Incluye validación de estructura, generación dinámica de manifest y compresión.

## Validación de estructura

**Skills:** Cada directorio en `.claude/skills/{nombre}/` debe contener:
- `SKILL.md` (frontmatter YAML + descripción)
- Máximo 150 líneas
- Campos requeridos: `name`, `description`

**Agents:** Archivos `.claude/agents/{name}.md` con frontmatter:
- `name`, `description`, `model` (opus, sonnet, haiku)
- Máximo 150 líneas

**Commands:** Archivos `.claude/commands/{name}.md` con frontmatter:
- `name`, `description`, `model`
- `context_cost` (low/medium/high)
- Máximo 150 líneas

## Generación dinámica de manifest

El manifest (`.claude-plugin/plugin.json`) se genera con conteos reales:

```bash
SKILLS=$(find .claude/skills -maxdepth 1 -type d | wc -l)
AGENTS=$(find .claude/agents -type f -name "*.md" | wc -l)
COMMANDS=$(find .claude/commands -type f -name "*.md" | wc -l)
```

Actualizar `capabilities` con valores reales antes de empaquetar.

## Proceso de exportación

1. Validar todos los ficheros (validación estructural)
2. Contar componentes
3. Actualizar plugin.json con conteos
4. Crear tar.gz con componentes seleccionados
5. Generar reporte con banner de éxito

## Versionado

La versión en plugin.json debe coincidir con CHANGELOG.md (sección actual).
No cambiar versión si validación falla.

## Flujo completo

Comandos `/plugin-export` y `/plugin-validate` orquestan este skill.
