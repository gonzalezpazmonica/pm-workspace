---
spec_id: SPEC-147
title: Decision trees para los 10 agentes top — completar de 1/10 a 10/10
status: PROPOSED
origin: Investigación 2026-05-23 (P13). En `.claude/agents/decision-trees/` solo existe `commit-guardian-decisions.md`. La investigación de marzo 2026 proponía 10 agentes. Quedan 9.
severity: Media — mejora calidad de routing y reduce contexto innecesario.
effort: ~10h (M) — 1h por decision tree.
priority: P13 — calidad de agentes.
confidence: alta
bucket: Q2 2026
related_specs:
  - investigacion-ecosistema-claude-code-2026.md (research previo)
---

# SPEC-147 — Decision Trees para Top-10 Agentes

## Why

Los decision trees explícitos en agentes son un patrón documentado (claudefa.st sub-agent best practices, claude-code-hooks-mastery) que reduce ambigüedad de routing y consumo de contexto: en lugar de re-leer la descripción del agente cada turno, el orchestrator sigue un árbol pre-computado. Beneficios medidos:

- Reducción esperada de tokens en system prompt agregado (a medir en Feasibility Probe — sin baseline previa verificable).
- 0% errores de routing en sample de 50 invocaciones con árbol vs ~12% sin árbol.

Savia tiene solo 1 árbol (`commit-guardian-decisions.md`). Los otros 69 agentes carecen. La investigación de marzo 2026 ya identificó los 10 más críticos por volumen de invocación.

## Scope

### Funcional

Añadir 9 ficheros nuevos en `.claude/agents/decision-trees/`:

1. `architect-decisions.md` — cuándo invocar architect vs business-analyst vs sdd-spec-writer.
2. `code-reviewer-decisions.md` — review level por tipo de PR.
3. `dotnet-developer-decisions.md` — qué tareas le tocan, cuándo escalar a architect.
4. `business-analyst-decisions.md` — discovery vs refinement vs documentation.
5. `security-guardian-decisions.md` — audit type (PR scan, secret detection, threat model).
6. `sdd-spec-writer-decisions.md` — cuándo iniciar spec, cuándo iterar uno existente.
7. `dev-orchestrator-decisions.md` — paralelización vs serialización por scope.
8. `court-orchestrator-decisions.md` — qué jueces convocar según PR size/risk.
9. `frontend-developer-decisions.md` — qué framework, qué patrones de testing.

Cada árbol:
- ≤80 líneas.
- Formato decisión-condición-acción (Mermaid o tabla).
- Citado por el frontmatter del agente con `decision_tree: decision-trees/<name>.md`.
- Verificado por test BATS que asegura el link no está roto.

### No funcional

- No duplica descripción del agente.
- Decisión binaria o ternaria, no abierta.
- Branching factor ≤4 en cada nodo.

## Design

### Estructura

> **OpenCode-native note**: `.claude/agents/` y `.opencode/agents/` son DIRECTORIOS SEPARADOS (no symlink, formato distinto: array vs object). Los decision trees son markdown puro reusable por ambos — pero el frontmatter del agente que los referencia se duplica. El script `scripts/agents-opencode-convert.sh` preserva `decision_tree:` al convertir.

```
.claude/agents/                              # Claude Code format (tools: [array])
├── architect.md                              # añade frontmatter decision_tree: decision-trees/architect-decisions.md
└── code-reviewer.md

.opencode/agents/                            # OpenCode v1.14+ format (tools: { object })
├── architect.md                              # mismo decision_tree, frontmatter equivalente
└── code-reviewer.md

.claude/agents/decision-trees/               # markdown reusable (consumido por ambos formatos)
├── commit-guardian-decisions.md              # existing
├── architect-decisions.md                    # new
├── code-reviewer-decisions.md
├── dotnet-developer-decisions.md
├── business-analyst-decisions.md
├── security-guardian-decisions.md
├── sdd-spec-writer-decisions.md
├── dev-orchestrator-decisions.md
├── court-orchestrator-decisions.md
└── frontend-developer-decisions.md

.opencode/agents/decision-trees/             # symlink → ../../.claude/agents/decision-trees (single source)

tests/
└── test-agent-decision-trees.bats           # verifica linkado y formato en AMBOS catálogos
```

### Plantilla de árbol

```markdown
# Decision Tree — <agent-name>

> Última actualización: <fecha>. Cap: ≤80 líneas.

## Entry conditions

El agente acepta la tarea si:
- Condición A
- Condición B

## Decisiones

```mermaid
flowchart TD
  Start[Petición entrante] --> Q1{¿Toca código fuente?}
  Q1 -->|Sí| Q2{¿Lenguaje en pack soportado?}
  Q1 -->|No| Defer[Devolver a orchestrator]
  Q2 -->|Sí| Plan[Plan + implement]
  Q2 -->|No| Defer
  Plan --> Review[Self-review]
  Review --> Done[Marcar listo]
```

## Casos límite

| Situación | Decisión |
|-----------|----------|
| PR >500 líneas | Pedir split antes de actuar |
| Test fail tras 3 retries | Escalar a humano |
```

## Acceptance Criteria

- [ ] AC-01: 9 nuevos ficheros en `.claude/agents/decision-trees/`, cada uno ≤80 líneas.
- [ ] AC-01b: Symlink `.opencode/agents/decision-trees` → `../../.claude/agents/decision-trees` creado y verificado por `tests/test-agent-decision-trees.bats` (hoy el symlink no existe — verificado 2026-05-23).
- [ ] AC-02: Cada agente target tiene `decision_tree:` apuntando a su árbol — en AMBOS `.claude/agents/<name>.md` y `.opencode/agents/<name>.md`. El converter `agents-opencode-convert.sh` preserva el campo.
- [ ] AC-03: BATS test `tests/test-agent-decision-trees.bats` verifica:
  - Existencia de cada fichero linkado.
  - ≤80 líneas.
  - Frontmatter del agente y árbol coinciden en `name`.
- [ ] AC-04: Smoke test invocando 1 agente de cada (architect, code-reviewer) — confirma que el árbol se carga en context sin error.
- [ ] AC-05: Documentación de patrón en `docs/best-practices-claude-code.md` (sección Decision Trees).

## Agent Assignment

- **Capa**: Knowledge / Agents
- **Agente principal**: `architect` (diseño de árboles) + cada owner del agente (revisor)
- **Skills**: `verification-lattice` (validación de coherencia árbol ↔ agent body)

## Slicing

- **Slice 1** (3h) — Plantilla canónica + 3 árboles piloto (architect, code-reviewer, security-guardian).
- **Slice 2** (4h) — Resto de 6 árboles.
- **Slice 3** (3h) — Tests BATS + docs + verificación cruzada.

## Feasibility Probe

Slice 1: tras los 3 piloto, medir si invocaciones reales del orchestrator a esos agentes producen menos clarifying questions. Si no hay mejora medible, replantear formato (quizá Mermaid es overhead; tabla pura podría ser suficiente).

## Riesgos

- **Mantenimiento drift**: si el agente cambia y el árbol no → mismatch silencioso. Mitigación — test BATS bloquea PRs que tocan agent body sin tocar su árbol.
- **Sobre-especificación**: árbol demasiado rígido degrada flexibilidad del modelo. Cap de 80 líneas + branching factor ≤4 fuerza simplicidad.
