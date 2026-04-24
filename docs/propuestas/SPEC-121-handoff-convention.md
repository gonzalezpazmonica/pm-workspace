---
id: SPEC-121
title: Handoff-as-function convention para SDD E1→E2→E3
status: PROPOSED
origin: Savia autonomous roadmap — Top pick #8 del research 2026-04-17
author: Savia
related: SAVIA-SUPERPOWERS-ROADMAP.md
priority: alta
---

# SPEC-121 — Handoff Convention

## Why

OpenAI Agents SDK popularizó el patrón **handoff-as-function**: un agente devolviendo el nombre de otro agente ES el routing. Esto simplifica enormemente transiciones E1→E2→E3 en SDD:

- Elimina `agent-notes-protocol.md` verboso
- Handoffs tipados (contract-first)
- Auditable en una línea
- Compatible con sandboxing (clave para `autonomous-safety.md`)

Savia actualmente usa `agent-notes-protocol.md` con frontmatter pesado y narrativa. Un handoff-as-function más ligero reduce tokens y mejora trazabilidad.

## Scope

1. **Diseñar** formato canónico de handoff en `.claude/agents/`:
   ```yaml
   handoff:
     to: code-reviewer
     spec: SPEC-120
     stage: E2
     context_hash: sha256:abc123
   ```

2. **Crear** `docs/rules/domain/agent-handoff-protocol.md` como nuevo contrato (reemplaza longform de `agent-notes-protocol.md` para handoffs simples).

3. **Mantener** `agent-notes-protocol.md` para casos complejos (research, multi-turn).

4. **Actualizar** 5 agentes representativos para usar la convención: `sdd-spec-writer`, `dotnet-developer`, `code-reviewer`, `test-engineer`, `court-orchestrator`.

5. **Validator** `scripts/validate-handoff.sh` (ya existe) extendido para el nuevo formato.

## Design

### Formato handoff-as-function

```yaml
# Al final del output de un agente, si necesita handoff:
---
handoff:
  to: code-reviewer              # agent name (canonical)
  spec: SPEC-120                 # spec reference
  stage: E2                      # SDD stage (E0..E4)
  context_hash: sha256:abc123... # deterministic hash of previous state
  reason: "Implementation complete, needs review"
  artifacts:
    - docs/propuestas/SPEC-120-spec-kit-alignment.md
    - .claude/skills/spec-driven-development/references/spec-template.md
---
```

### Cuándo usar cuál

| Situación | Protocolo |
|---|---|
| Handoff simple E1→E2 con artefactos claros | **handoff-as-function** (SPEC-121) |
| Research multi-turn, discusión, decisión compleja | **agent-notes-protocol** existente |
| Broadcasting a múltiples agentes | **agent-notes-protocol** existente |

## Acceptance Criteria

- [ ] AC-01 `docs/rules/domain/agent-handoff-protocol.md` creado con ejemplo runnable
- [ ] AC-02 5 agentes (sdd-spec-writer, dotnet-developer, code-reviewer, test-engineer, court-orchestrator) actualizados con sección "Handoff format"
- [ ] AC-03 `scripts/validate-handoff.sh` extendido con validación del nuevo formato YAML
- [ ] AC-04 Test bats verifica que un handoff válido pasa y uno malformado falla
- [ ] AC-05 Documentación cruzada en `agent-notes-protocol.md` cuando aplicar uno vs otro
- [ ] AC-06 CHANGELOG entry

## Agent Assignment

Capa: Architecture + protocols
Agente: architect + tech-writer

## Slicing

- Slice 1: `agent-handoff-protocol.md` spec + 1 agente piloto
- Slice 2: Extender a 4 agentes restantes + validator
- Slice 3: Tests + docs + CHANGELOG

## Feasibility Probe

Time-box: 45 min. Riesgo principal: ruptura de agentes existentes que dependan del `agent-notes-protocol`. Mitigación: los cambios son **aditivos** — `handoff:` es nueva sección opcional, no reemplaza nada obligatorio.

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Agentes ignoran el nuevo formato | Media | Bajo | Documentado con ejemplos; validator avisa sin bloquear |
| Context hash inconsistente | Baja | Medio | Helper `scripts/compute-context-hash.sh` |
| Duplicación con agent-notes-protocol | Media | Bajo | Tabla explícita "cuándo usar cuál" |

## Referencias

- [OpenAI Agents SDK](https://github.com/openai/openai-agents-python) — patrón original
- `docs/agent-notes-protocol.md` — protocolo longform existente
- `scripts/validate-handoff.sh` — validator existente
