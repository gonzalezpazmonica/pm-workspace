---
globs: [".opencode/agents/**"]
---

# Handoff Templates — Transiciones Estandarizadas entre Agentes

> 7 plantillas para garantizar contexto suficiente en cada transición.

---

## 1. Standard Handoff

```yaml
from: "{agente_origen}"
to: "{agente_destino}"
task_ref: "{AB#ID o spec-id}"
context:
  summary: "Qué se hizo y por qué se transfiere"
  files_modified: ["path/to/file.cs"]
  decisions_made: ["Elegido patrón X por Y"]
dependencies:
  requires: ["fichero o artefacto necesario"]
  blocks: ["tarea que espera este resultado"]
expected_output: "Qué debe producir el receptor"
```

## 2. QA Pass

```yaml
from: "{test-runner|test-engineer}"
to: "{orquestador}"
verdict: "PASS"
evidence:
  test_output: "dotnet test → 42/42 passed"
  coverage: "87.3% (min: 80%)"
  screenshots: ["output/screenshots/..." ]  # obligatorio si UI
  performance: "p95 < 200ms"  # si aplica
files_verified: ["Service.cs", "Controller.cs"]
```

**Regla**: Sin `evidence` completa → el handoff se rechaza.

## 3. QA Fail

```yaml
from: "{test-runner|test-engineer}"
to: "{developer}"
verdict: "FAIL"
failures:
  - test: "CreateOrder_WithInvalidData_Returns400"
    error: "Expected 400, got 500"
    file: "OrderController.cs"
    line: 47
    suggestion: "Falta validación de input antes de SaveAsync"
  - test: "..."
context:
  total_tests: 42
  passed: 40
  failed: 2
  attempt: 1  # de máx 3
```

**Regla**: Cada fallo debe incluir file + line + suggestion. "Falla el test" sin contexto NO es válido.

## 4. Escalation

```yaml
from: "{agente}"
to: "HUMANO"
reason: "max_retries_exceeded | unrecoverable_error | ambiguous_spec"
attempts:
  - attempt: 1
    action: "Intenté X"
    result: "Falló por Y"
    model: "haiku"
  - attempt: 2
    action: "Intenté Z"
    result: "Falló por W"
    model: "sonnet"
  - attempt: 3
    action: "Intenté V"
    result: "Falló por U"
    model: "opus"
recommendation: "Sugiero que el humano revise la spec en línea 23"
files_affected: ["path/to/file"]
```

**Regla**: Escalación sin contexto de intentos previos → bloqueada.

## 5. Phase Gate (SDD)

```yaml
phase_from: "architect"
phase_to: "sdd-spec-writer"
gate: "architecture_approved"
artifacts:
  produced: ["output/arch/layer-assignment.md"]
  validated: true
quality_score: 0.85  # si aplica consensus
blockers: []  # lista vacía = gate passed
next_phase_input: "Usar layer-assignment.md como base para la spec"
```

Fases: analyst → architect → spec-writer → developer → test-engineer → code-reviewer

## 6. Sprint Review

```yaml
from: "orquestador"
to: "stakeholders"
sprint: "2026-06"
summary: "3 PBIs completados, 1 parcial"
metrics: { velocity: 38, completion: "92%", coverage_delta: "+5.2%" }
highlights: ["Feature X"]
risks: ["Migration Y retrasada 2 días"]
next_actions: ["Priorizar migration Y"]
```

## 7. Status Report

```yaml
from: "{agente}"
to: "orquestador"
task_ref: "{AB#ID}"
status: "in_progress | blocked | completed"
progress: "3/5 slices done"
blockers: []
tokens_used: 12500
```

---

## Validación

Un handoff es **válido** si: (1) campos obligatorios presentes, (2) files_modified existen, (3) evidence con output real, (4) attempt ≤ 3, (5) termination_reason ∈ `{completed, user_abort, token_budget, stop_hook, max_turns, unrecoverable_error}` (SPEC-TERMINAL-STATE-HANDOFF)

## Fork vs Subagent — Decision (SPEC-FORK-VS-SUBAGENT-GUIDE)

| Dimension | Fork | Subagent (Task) |
|---|---|---|
| Contexto | Heredado del padre | Fresco aislado |
| Cache | 90% descuento prefijo | Sin cache |
| Output | Inline en conversación | Solo resumen |
| Uso | Batch N items similares | Tarea aislada |

Fork → N items con mismo prompt base. Subagent → aislamiento/contexto fresco.
