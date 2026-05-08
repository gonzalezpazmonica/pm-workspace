# Context Engineering Improvements — Documentación

> Mejoras basadas en investigación del AI Engineering Guidebook (2025), Anthropic Skills repo, y prompt structure best practices.

---

## Resumen

Este módulo introduce 5 mejoras al sistema de Context Engineering de pm-workspace, alineándolo con las mejores prácticas documentadas en el AI Engineering Guidebook y la estructura de prompt de 10 capas.

---

## Mejora 1: Example Patterns (Few-shot en Commands)

Los ejemplos concretos de input/output son el tipo de contexto más potente para guiar el comportamiento de un LLM. Se añade una sección `## Ejemplos` con pares positivo (✅) y negativo (❌) a los commands más críticos.

**Regla:** `docs/rules/domain/example-patterns.md`
**Commands piloto:** `project-audit`, `sprint-plan`, `spec-generate`, `debt-track`, `risk-log`

---

## Mejora 2: /eval-output (LLM-as-a-Judge)

Nuevo comando que implementa G-Eval — evaluación de outputs con scoring cuantitativo (1-10) por criterios definidos. Incluye modo Arena para comparación A/B de dos outputs.

**Comando:** `.opencode/commands/eval-output.md`
**Criterios:** `docs/rules/domain/eval-criteria.md` (4 tipos: report, spec, code, plan)

---

## Mejora 3: Entity Memory

Extiende el sistema de memoria con Entity Memory — memoria estructurada que trackea entidades específicas (stakeholders, componentes, decisiones) de forma persistente entre sesiones.

**Comando:** `.opencode/commands/entity-recall.md`
**Script:** `scripts/memory-store.sh` (nuevo subcomando `entity`)

---

## Mejora 4: Tool Discovery (Capability Groups)

Agrupa los 360+ comandos en 15 capability groups semánticos para reducir el tool overload. Los agentes y el NL-resolver buscan primero en el grupo relevante.

**Regla:** `docs/rules/domain/tool-discovery.md`
**Mapa:** `docs/capability-groups.md`

---

## Mejora 5: Prompt Structure Compliance

Alinea pm-workspace con la estructura de 10 capas de prompt óptimo, añadiendo las capas faltantes: Reasoning Guidance (razonamiento paso a paso) y Output Templates (formato de salida concreto).

**Regla:** `docs/rules/domain/prompt-structure.md`

---

## Tests

```bash
bash scripts/test-context-eng-improvements.sh
```

El test suite valida: existencia de ficheros, frontmatter, secciones requeridas, límites de líneas, funcionalidad de entity memory, cross-references entre ficheros, y presencia de documentación.

---

## Fuentes

- AI Engineering Guidebook (Pachaar & Chawla, 2025) — Context Engineering, AI Agents, MCP, LLM Evaluation
- Anthropic Skills repo (github.com/anthropics/skills) — formato oficial de skills
- Prompt structure image — modelo de 10 capas para prompts óptimos
