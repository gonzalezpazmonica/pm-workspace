---
spec_id: SE-238
title: "Skills Schema Descubrible Programáticamente"
status: IMPLEMENTED
created: 2026-06-28
resolved_at: "2026-07-02"
implementation_pr: "#889"
author: savia
context_tier: L2
token_budget: 550
inspired_by: "Proto (Arc Institute, 2026) — get_tool_schema MCP, get_tool_example, llms.txt"
---

# SE-238: Skills Schema Descubrible Programáticamente

## Motivación

Proto expone `get_tool_schema` y `get_tool_example` como herramientas MCP que devuelven el esquema exacto de inputs/outputs de cualquier tool. También genera `llms.txt` como índice de toda la documentación en formato texto plano optimizado para LLMs. La API es self-describing.

Savia tiene `AGENTS.md` y `SKILLS.md` como índices legibles por humanos, y `opencode.json` con config de agentes pero sin schema de inputs/outputs. No existe un `skills-schema.json` generado automáticamente que un LLM externo o un agente pueda consumir para saber cómo usar un skill programáticamente.

**Problema**: un agente que necesita seleccionar el skill correcto debe leer hasta 107 ficheros SKILL.md completos, o confiar en la descripción de SKILLS.md que es legible-por-humanos pero no tiene campos estructurados para routing automático.

## Schema skills-schema.json

### Formato de cada entrada

```json
{
  "skill_id": "savia-memory",
  "description": "Usar cuando se lee, escribe, busca o consolida la memoria persistente entre sesiones de Savia.",
  "tags": ["memory", "persistence", "session"],
  "inputs_hint": "comando (recall|save|stats), query opcional",
  "outputs_hint": "resultados de memoria o confirmación de escritura",
  "example_trigger": "Guarda esta decisión en memoria",
  "skill_path": ".opencode/skills/savia-memory/SKILL.md"
}
```

### Campos obligatorios

- `skill_id`: nombre del directorio del skill (único)
- `description`: primera línea de descripción del SKILL.md (o campo `description` del frontmatter)
- `skill_path`: path relativo al SKILL.md

### Campos opcionales (extraídos si existen)

- `tags`: extraídos del frontmatter si existe campo `tags`
- `inputs_hint`: primera línea de la sección `## Inputs` o `## Parámetros` si existe
- `outputs_hint`: primera línea de la sección `## Outputs` o `## Resultado` si existe
- `example_trigger`: primera línea de `## Cuándo usar` o `## Triggers`

## Generación automática

`scripts/skills-schema-generate.sh`:
1. Itera sobre todos los directorios en `.opencode/skills/*/SKILL.md`
2. Para cada SKILL.md: extrae `skill_id` (nombre del directorio), `description` (frontmatter o primera línea H1), y campos opcionales si existen
3. Genera `skills-schema.json` en la raíz del repo con array de objetos
4. También genera `skills-schema.md` (versión legible) para inclusión en `.llms.txt`
5. Es idempotente: mismo output para el mismo estado del repo

## .llms.txt

Índice en la raíz del repo en formato texto plano, optimizado para ingesta por LLMs:

```
# Savia pm-workspace — LLM-readable index
## Skills (N)
/skills-schema.json — schema programático de todos los skills
/SKILLS.md — índice legible de skills
## Agents (81)
/AGENTS.md — catálogo de agentes
## Rules
/docs/rules/INDEX.md — índice de reglas de dominio
## Specs
/docs/propuestas/ — especificaciones técnicas
```

## Consulta vía MCP

El `skills-schema.json` puede ser expuesto vía MCP como `get_skill_schema(skill_id)` en futuras iteraciones. Por ahora se consume directamente como fichero JSON.

## Tests

Ver `tests/test-se238-skills-schema.bats` — 12 tests.

## Criterio de éxito

- `skills-schema-generate.sh` genera `skills-schema.json` con ≥ 50 entradas (hay 107 skills)
- Cada entrada tiene `skill_id`, `description`, `skill_path`
- `.llms.txt` existe en la raíz del nido
- El script es idempotente
- Los 12 tests BATS pasan en verde
