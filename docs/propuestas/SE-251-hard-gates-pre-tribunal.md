---
id: SE-251
title: "Hard gates mecanicos pre-tribunal para decisiones criticas"
status: PROPOSED
priority: P2
effort: M (10h — S1 4h gates + S2 3h integracion court-orchestrator + S3 3h tests)
origin: Investigacion output/research/20260624-santanderai-github-analysis.md §3.2
author: Savia
related:
  - .opencode/agents/court-orchestrator.md
  - docs/rules/domain/autonomous-safety.md
  - scripts/risk-scoring.sh
proposed_at: "2026-06-28"
era: 251
roi: Medio — mejora integridad de decisiones de alto impacto; requiere cambios en agentes existentes
---

# SE-251 — Hard Gates Mecanicos Pre-Tribunal

## Objective

Implementar gates mecanicos deterministicos (sin LLM) que se ejecutan ANTES de convocar el
court-orchestrator o el recommendation-tribunal para decisiones de alto impacto: merge de PR,
deploy de infra, escritura en Azure DevOps.

El problema: los tribunales actuales operan con jueces LLM en paralelo. Para decisiones donde
la condicion de bloqueo es clara y binaria (spec no aprobada, reviewer no resoluble, risk_score
critico), el tribunal es innecesariamente caro. Deberia convocarse solo si los gates pasan.

Patron de referencia: pipeline con hard_gates deterministicos pre-LLM. Si un gate falla,
la decision se escala a humano sin invocar ningun juez LLM.

## Principles affected

- §5 Humans decide — un gate bloqueado produce escalacion humana, no decision autonoma.
- §9 Supervised execution — los gates son hard stops, no advertencias.
- §4 Reversible — cada gate tiene bypass explicito documentado para tests.

## Design

### Overview

```
Decision critica solicitada (merge PR / deploy infra / write DevOps)
        |
scripts/pre-tribunal-gates.sh --decision <type> --context <json>
        -> exit 0: PASS (todos los gates pasan) -> invocar tribunal normalmente
        -> exit 1: BLOCK (un gate fallo) -> escalar a humano, no invocar tribunal
        -> exit 2: SKIP (type no clasificada como critica) -> flujo normal
```

### Gates (en orden de evaluacion)

**G1: Spec Approval Gate**
Bloquea si la decision afecta una feature y no hay spec APPROVED/IMPLEMENTED asociada.
spec_status in (PROPOSED, DRAFT, NONE) -> BLOCK "feature without approved spec"

**G2: Autonomous Reviewer Gate**
Bloquea si AUTONOMOUS_REVIEWER no es resoluble (ver autonomous-safety.md cadena de resolucion).
savia_autonomous_reviewer() returns empty -> BLOCK "reviewer unresolvable"

**G3: Risk Score Gate**
Bloquea si risk_score supera el umbral critico (scripts/risk-scoring.sh).
risk_score > RISK_GATE_THRESHOLD (default 0.8) -> BLOCK "risk score critical"

**G4: Branch Safety Gate**
Bloquea si la rama de destino es main/develop y la rama fuente no es agent/* o nido/*.
target main/develop AND source not (agent/|nido/) -> BLOCK

### I6Q Quality Check (integracion tribunal)

Cuando el tribunal es convocado, verificar calidad de rationale por juez:
- Rationale < MIN_RATIONALE_TOKENS (default 50) -> tribunal solicita retry antes de agregar.
- Max 2 retries por juez. Si sigue insuficiente -> ESCALATE.

### Components

| Name | Kind | Purpose |
|---|---|---|
| `scripts/pre-tribunal-gates.sh` | bash | Gates G1-G4 deterministicos |
| `.opencode/agents/court-orchestrator.md` | patch | Invocar gates antes de convocar tribunal |
| `tests/test-se251-pre-tribunal-gates.bats` | test suite | Verificacion de cada gate |

### Contracts

pre-tribunal-gates.sh:
- Input: --decision merge|deploy|devops + --context json
- Output JSON: {"gate":"G1","verdict":"BLOCK","reason":"...","escalate_to":"human"}
- Exit 0: PASS; Exit 1: BLOCK; Exit 2: SKIP

### Configuration

```bash
RISK_GATE_THRESHOLD=0.8         # threshold para G3 (0.0-1.0)
MIN_RATIONALE_TOKENS=50         # tokens minimos en rationale de un juez
PRETRIBUNAL_GATES_ENABLED=true  # false para deshabilitar en tests
SPEC_GATE_ENABLED=true          # false para proyectos sin specs obligatorias
```

## Acceptance criteria

1. Con spec en estado PROPOSED, G1 bloquea y sale codigo 1.
2. Con AUTONOMOUS_REVIEWER vacio, G2 bloquea y sale codigo 1.
3. Con risk_score > 0.8, G3 bloquea y sale codigo 1.
4. Con rama main como destino y fuente feature/foo, G4 bloquea.
5. Con todos los gates en PASS, sale codigo 0.
6. Decision type desconocida sale codigo 2 (SKIP), no 1 (BLOCK).
7. Con PRETRIBUNAL_GATES_ENABLED=false, siempre sale 0.
8. BATS suite >= 12 tests, calidad >= 80.
9. Script bash puro, sin LLM calls.

## Out of scope

- E3 entropy commit-reveal (requiere spec dedicada).
- CDL/DIU governance metrics (requieren telemetria longitudinal de 30+ dias).
- Modificacion del recommendation-tribunal-orchestrator (solo court-orchestrator en esta spec).

## Dependencies

- Blocked by: ninguno (risk-scoring.sh ya existe).
- Blocks: ninguno.

## Migration path

Opt-in via PRETRIBUNAL_GATES_ENABLED=true. Court-orchestrator no se rompe — extiende
el inicio con bloque condicional. Con el flag deshabilitado: comportamiento identico al actual.

## Impact statement

Reduce el coste de LLM en decisiones donde la condicion de bloqueo es determinista.
G2 (reviewer unresolvable) y G4 (branch safety) son conocidos antes del request: no necesitan
deliberacion de 4-5 jueces. I6Q mejora la calidad de los veredictos que si llegan al tribunal.
