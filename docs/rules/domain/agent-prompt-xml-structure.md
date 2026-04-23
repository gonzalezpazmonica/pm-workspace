# Agent Prompt XML Structure (SE-068)

> Canonical XML tag set for Opus 4.7 agent prompts. Source: Anthropic Opus 4.7 migration guide — "Put longform data at the top of your prompt, above your query. Queries at the end can improve response quality by up to 30% on complex, multi-document inputs."

## When to use

- Agent uses model `claude-opus-4-7` with `effort: xhigh` or `max`
- Prompt is long (≥60 lines) or handles multi-document input
- Agent is invoked frequently (cost of structure amortizes)

NOT for:
- Short utility agents (≤40 lines narrative prompt)
- Cheap-tier agents on sonnet/haiku (simpler prompts work fine)

## Canonical tag set (6 tags)

| Tag | Purpose | Required? |
|---|---|---|
| `<role>` | One-paragraph identity + domain expertise | Optional (frontmatter covers) |
| `<instructions>` | Operational guidance: what the agent does per turn | Required |
| `<context_usage>` | How to consume files/diffs/memory/project state | Required for agents that read context |
| `<examples>` | 3-5 wrapped `<example>` blocks showing good behavior | Optional, high value when available |
| `<constraints>` | Non-negotiables: permissions, safety, scope limits | Required |
| `<output_format>` | Expected structure of agent's final output | Required |

## Order (top-to-bottom)

```
1. Frontmatter (YAML)
2. Narrative role + expertise (human-readable, legacy-compatible)
3. <role> (optional, if narrative was skipped)
4. <instructions>
5. <context_usage>
6. <examples>
7. <constraints>
8. <output_format>
—— user turn (query) arrives AFTER this structure ——
```

## Example skeleton

```markdown
---
name: architect
model: claude-opus-4-7
permission_level: L1
---

Eres un Senior Software Architect con dominio en .NET…
[legacy narrative preserved]

<instructions>
Cuando analizas una tarea: (1) lee el CLAUDE.md del proyecto, (2) mapea la
capa correspondiente, (3) propón el diseño con trade-offs explícitos.
</instructions>

<context_usage>
Al recibir un spec, extrae las reglas de negocio (RN-XXX-NN), las dependencias
y los componentes afectados. Cita fragmentos literales cuando referencies.
</context_usage>

<constraints>
- permission_level: L1 (read-only + bash restringido)
- Respeta las reglas de docs/rules/domain/layer-assignment-matrix.md
- Nunca proponer cambios sin Spec SDD aprobada (Rule #8)
</constraints>

<output_format>
Emite:
1. Decisión arquitectónica (1 párrafo)
2. Trade-offs (bullets)
3. Pasos siguientes (ordered list)
</output_format>
```

## Migration checklist

Para migrar un agent existente:

- [ ] Agent es opus-4-7 con effort xhigh/max?
- [ ] Prompt ≥ 60 líneas?
- [ ] Identificar bloques existentes que encajan en `<instructions>`, `<context_usage>`, `<constraints>`, `<output_format>`
- [ ] Añadir tags sin reescribir contenido (preservar tono y decisiones existentes)
- [ ] Verificar con `scripts/opus47-compliance-check.sh --xml-tags`
- [ ] BATS test asserts tag presence

## Anti-patterns

- ❌ XML tags en agentes haiku/sonnet-4-6 ligeros (overhead sin beneficio)
- ❌ Duplicar contenido narrativo en XML tags (elegir uno)
- ❌ Tags custom fuera del set canónico (no hay `<critical>`, `<important>`, `<notes>`)
- ❌ Query del usuario insertada en medio de la estructura (debe ir AL FINAL)

## Evidencia

- Anthropic Opus 4.7 migration guide (2026-01): up to 30% quality improvement on multi-doc inputs with structured XML + query-at-end
- Complementary to SE-066 (Reporting Policy), SE-067 (Fan-out), SE-069 (Context rot)

## Referencias

- Propuesta: `docs/propuestas/SE-068-xml-tags-top-tier-agents.md`
- Opus 4.7 analysis: conversación 2026-04-23
