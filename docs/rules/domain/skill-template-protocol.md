---
context_tier: L2
token_budget: 812
---

# Skill Template Protocol — SE-153

> Plantilla canónica para crear nuevas skills. Patrón "Authoritative Paths First" (inspirado en flowsint). Reduce coste de contexto y elimina inferencia incorrecta de firmas/paths por agentes.

## Por qué

Antes de SE-153 las SKILL.md mezclaban tutorial explicativo y referencia técnica. Los agentes leen top-down con presupuesto limitado de contexto. Si los paths canónicos están al final de la skill, el agente:

1. Pierde contexto antes de llegar a ellos.
2. Empieza a inventar firmas o paths basándose en convenciones genéricas.
3. Genera código que no compila o referencia ficheros inexistentes.

Solución: **paths primero, prosa después**. Sección obligatoria `## Authoritative Paths` justo tras el título de la skill, antes de cualquier tutorial o decisión.

## Ubicación

```
.claude/skills/_template/SKILL.md   ← canónica
.opencode/skills/_template/SKILL.md ← visible vía symlink
```

`.opencode/skills` es un symlink a `../.claude/skills`, por lo que el template aparece en ambos paths automáticamente.

## Cómo usar

1. Copiar el directorio:
   ```
   cp -r .claude/skills/_template .claude/skills/<nombre-skill>
   ```
2. Editar `SKILL.md`:
   - Reemplazar todos los `<placeholder>` por valores reales.
   - Actualizar frontmatter `name`, `description`, `tags`.
   - Borrar el bloque HTML "HOW TO USE THIS TEMPLATE".
3. Mantener tamaño ≤150 líneas (Rule #11).
4. Si la skill no es orquestadora (no invoca subagentes), borrar la sección `## Subagent Scope Guard`.

## Reglas duras

- **Authoritative Paths VA PRIMERO** después del título. No después del workflow, no al final. Auditado por BATS.
- **NUNCA inventar paths**: si la skill necesita un path no documentado, primero añadirlo a la tabla `Authoritative Paths`, luego usarlo.
- **NUNCA asumir firmas**: si una firma no está en los paths declarados, leer el código fuente directamente.
- **El template NO se carga en runtime**: los generadores excluyen `_template` explícitamente. Cualquier nuevo generador de catálogo DEBE excluirlo.

## Migración

Opt-in. Las skills existentes no se migran masivamente. Una skill se actualiza al patrón cuando se toca por otra razón (refactor, fix, ampliación). Esto evita PRs ruidosos sin valor.

Lista priorizada para futuras migraciones (alta densidad de paths/handoffs):

- `spec-driven-development` (orquesta varios agentes)
- `pbi-decomposition` (handoff arquitectura ↔ análisis)
- `feasibility-probe` (paths a specs + scripts)
- `code-improvement-loop` (paths a guards + memory)
- `consensus-validation` (paths a jueces)

## Validación

- `bats tests/test-skill-template.bats` — 34/34 tests, audit 88/100.
- `bash scripts/skills-md-generate.sh --check` — drift detection no incluye `_template`.
- `bash scripts/resolver-md-generate.sh --check` — RESOLVER.md no incluye `skill:_template`.

## Referencias

- ROADMAP: `docs/ROADMAP.md` — Era 197 / Tier 1, SE-153.
- Patrón fuente: análisis flowsint 2026-05-30 (graph indexing + enricher pattern + authoritative paths first).
- Template: `.claude/skills/_template/SKILL.md`.
- Tests: `tests/test-skill-template.bats`.
- Generadores: `scripts/skills-md-generate.sh`, `scripts/resolver-md-generate.sh`.
