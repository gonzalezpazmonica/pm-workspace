---
id: SE-087
title: SE-087 — Design-an-interface skill (parallel sub-agents for module interface alternatives)
status: APPROVED
origin: mattpocock/skills/design-an-interface (MIT) — análisis 2026-04-27
author: Savia
priority: media
effort: M 4h
related: SE-074 parallel-specs-orchestrator, SE-082 architectural-vocabulary, architect agent
approved_at: "2026-04-27"
applied_at: null
expires: "2026-06-27"
era: 190
---

# SE-087 — Design-an-interface skill

## Why

Cuando se diseña una interface nueva (un módulo, una API, un schema), la primera idea suele ser la única considerada. Pocock automatiza la generación de **3-4 alternativas radicalmente distintas** vía sub-agentes paralelos, lo que destapa trade-offs antes de cerrar la decisión:

- Una alternativa optimiza por simplicidad de uso
- Otra por flexibilidad/composability
- Otra por type-safety estricto
- Otra por minimal-state / functional pureness

pm-workspace ya tiene infra para spawn paralelo (SE-074 parallel-specs-orchestrator + worktrees + bounded concurrency). Falta un skill que la use para problema diferente: no "spec parallel", sino "interface design alternatives parallel".

Coste de no adoptar: Mónica (o agente) cierra interface al primer diseño viable, descubre los trade-offs en code-review o en bug-fix posterior, paga refactor. Coste de adoptar: ~120 LOC de skill markdown + reusa SE-074 worktree infra (zero código nuevo de spawn).

## Scope (M 4h, slice único)

### 1. `.opencode/skills/design-an-interface/SKILL.md` (clean-room, ~120 LOC)

Trigger: usuaria/agente menciona "diseña la interfaz", "design this module", "varias alternativas", "/design-interface"

Proceso documentado:

1. **Capture** — agente principal lee el problema (módulo a diseñar, constraints, dependencias)
2. **Spawn** — usar Agent tool con `subagent_type=architect` (o general-purpose si overhead) — N=3 sub-agentes en paralelo, cada uno con prompt distinto:
   - Agente A: "diseño minimalista, optimiza por simplicidad de uso del caller"
   - Agente B: "diseño compositional, optimiza por flexibilidad y reuso"
   - Agente C: "diseño type-safe estricto, optimiza por errores capturados en compile-time"
   - (Opcional D: "diseño functional pure, optimiza por testability sin mocks")
3. **Compare** — agente principal recoge los 3-4 outputs y produce tabla comparativa: signature / pros / cons / cuándo elegir cada uno
4. **Decide** — agente principal recomienda UNO con razonamiento, NO automerge — usuaria decide

Vocabulario obligatorio (cita SE-082): Module, Interface, Seam, Adapter, Depth, Locality.

Atribución MIT a `mattpocock/skills/design-an-interface/SKILL.md`.

### 2. Bridge a SE-074 si aplica

Si el problema es lo bastante grande (>1h por agente), el skill puede pasar la coordinación al `parallel-specs-orchestrator` adaptado a "design tracks" en vez de "spec tracks". Por defecto, sub-agentes son ligeros (un single-turn con contexto comprimido) y NO necesitan worktrees — es paralelismo intra-sesión, no inter-worktree.

### 3. Tests BATS estáticos

- SKILL.md compliant SE-084 (frontmatter + Use when + ≤120 LOC)
- Cita SE-082 architectural-vocabulary (cross-ref)
- Cita SE-074 si existe sección de "for big designs"

## Acceptance criteria

- [ ] AC-01 `.opencode/skills/design-an-interface/SKILL.md` ≤120 LOC compliant SE-084
- [ ] AC-02 Atribución MIT a Pocock en header
- [ ] AC-03 Cross-reference a `architectural-vocabulary.md` (SE-082)
- [ ] AC-04 Cross-reference a SE-074 (mencionado, no obligatorio para casos pequeños)
- [ ] AC-05 Skill describe explícitamente las N=3 alternativas y sus criterios
- [ ] AC-06 Skill no auto-merges — la decisión queda en usuaria
- [ ] AC-07 Tests BATS ≥6 estáticos
- [ ] AC-08 CHANGELOG fragment

## No hace

- NO añade infra de spawn nueva — usa Agent tool existente
- NO crea worktrees automáticamente — sólo si el problema es grande y la usuaria lo decide
- NO genera código de la implementación elegida — separa diseño de impl (que va a SDD spec normal)
- NO sustituye `architect` agent — éste es invocable PARA un problema concreto; architect es role-based más amplio

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| 3 sub-agentes producen outputs inconsistentes en vocabulario | Media | Bajo | Cada sub-agente recibe SE-082 vocabulary referencia en su prompt |
| Token cost alto (3-4 sub-agentes paralelos) | Media | Medio | Skill aclara: usar para decisiones de interfaz "load-bearing", no para CRUD trivial |
| Sub-agentes copian-paste el mismo diseño | Media | Bajo | Prompts deliberadamente divergentes (4 axes ortogonales) |

## Dependencias

- ✅ Agent tool con subagent_type=architect existe
- ✅ SE-074 parallel-specs-orchestrator implementado (no bloqueante para casos pequeños)
- **Recomendado**: SE-082 architectural-vocabulary IMPLEMENTED antes (vocabulario en outputs); si después, los sub-agentes usan vocabulario libre y SE-082 corregirá retroactivamente
- Sin bloqueantes externos.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Skill | `.opencode/skills/design-an-interface/SKILL.md` | autoload via AGENTS.md regen |

OpenCode v1.14 tiene Agent spawning equivalente vía AGENTS.md sub-agent definitions (SE-078). El skill funciona idéntico — la diferencia es sólo cómo el frontend ejecuta `subagent_type` (Claude Code: built-in; OpenCode: vía AGENTS.md → router).

### Verification protocol

- [ ] Smoke: skill invocable desde Claude Code, output incluye 3 alternativas + comparativa
- [ ] Smoke: skill invocable desde OpenCode v1.14 con AGENTS.md routing equivalente

### Portability classification

- [x] **PURE_DOCS**: markdown puro. Cross-frontend trivial vía SE-078 AGENTS.md.

## Referencias

- `mattpocock/skills/design-an-interface/SKILL.md` — fuente
- SE-082 architectural-vocabulary — vocabulario obligatorio
- SE-074 parallel-specs-orchestrator — infra paralelismo (referenciable, no obligatorio)
- John Ousterhout "A Philosophy of Software Design" — multi-design exploration discipline
