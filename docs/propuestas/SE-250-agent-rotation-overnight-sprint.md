---
id: SE-250
title: "Agent Rotation en overnight-sprint — token exhaustion recovery"
status: IMPLEMENTED
priority: P1
effort: M (8h — S1 3h detector + S2 3h rotation logic + S3 2h tests)
origin: Investigacion output/research/20260624-santanderai-github-analysis.md §3.1
author: Savia
related:
  - .opencode/skills/overnight-sprint/SKILL.md
  - docs/rules/domain/autonomous-safety.md
  - scripts/savia-env.sh
proposed_at: "2026-06-28"
resolved_at: "2026-07-02"
implementation_pr: "#891"
era: 250
roi: Alto — elimina la principal causa de fallo silencioso de overnight-sprint
---

# SE-250 — Agent Rotation en overnight-sprint

## Objective

Anadir a overnight-sprint un mecanismo de deteccion de token exhaustion y rotacion
automatica de tier cuando una iteracion falla por esta causa.

El problema: overnight-sprint falla silenciosamente cuando el modelo agota el contexto.
Hoy AGENT_MAX_CONSECUTIVE_FAILURES decrements identico para fallo por tokens que por logica.
Tres fallos por tokens matan el sprint con trabajo sin realizar.

Solucion: un detector bash (sin LLM) clasifica la causa del fallo. Si es token_exhaustion,
el sprint escala al siguiente tier y reintenta la misma tarea. La rotacion es
fast->mid->heavy, requiriendo flag explicito para heavy.

## Principles affected

- §5 Humans decide — la escalacion a heavy tier requiere ALLOW_HEAVY_ESCALATION=true explicito.
- §4 Reversible — cada tarea registra su tier en results.tsv para auditoria.
- §9 Supervised execution — AGENT_MAX_CONSECUTIVE_FAILURES sigue siendo el hard stop.

## Design

### Overview

```
iteration N fails (exit != 0)
        |
scripts/detect-token-exhaustion.sh --log <log_file>
        -> CAUSE=token_exhaustion (exit 0)
        -> CAUSE=logic_error (exit 2)
        -> log not found (exit 1)
        |
        v (si token_exhaustion Y tier < limit)
TIER = escalate(current_tier)
results.tsv += tier_escalated=true, original_tier, new_tier
Retry misma tarea con TIER escalado
```

### Detector: `scripts/detect-token-exhaustion.sh`

Input: `--log <path>`
Output stdout: `CAUSE=token_exhaustion|logic_error|unknown`

Heuristicas bash puro (deterministico, sin LLM):
```
grep -qiE "context_length_exceeded|max_tokens.*exceeded|prompt.*(too long|exceeds)|input.*too long"
```

Si ninguna senal -> CAUSE=unknown -> NO escalar (conservativo).

### Tier escalation table

| current_tier | next_tier | Condicion |
|---|---|---|
| fast | mid | siempre que haya token_exhaustion |
| mid | heavy | solo si ALLOW_HEAVY_ESCALATION=true |
| heavy | — | no escala mas; sprint aborta |

### Components

| Name | Kind | Purpose |
|---|---|---|
| `scripts/detect-token-exhaustion.sh` | bash | Clasificador causa de fallo (sin LLM) |
| `.opencode/skills/overnight-sprint/SKILL.md` | patch | Anadir bloque Token Exhaustion Recovery |
| `tests/test-se250-agent-rotation.bats` | test suite | Verificacion detector y rotation |

### Configuration

```bash
ALLOW_HEAVY_ESCALATION=false       # true para escalar a heavy (caro)
AGENT_TOKEN_EXHAUSTION_RETRY=true  # false para deshabilitar rotation
MAX_TIER_ESCALATIONS_PER_SPRINT=3  # limite total de escalaciones por sesion
```

## Acceptance criteria

1. `scripts/detect-token-exhaustion.sh --log /dev/null` sale codigo 1 (log no encontrado).
2. Log con "context_length_exceeded" -> exit 0 y CAUSE=token_exhaustion.
3. Log con fallo de sintaxis bash -> exit 2 y CAUSE=logic_error.
4. Con ALLOW_HEAVY_ESCALATION=false (default), tier nunca supera mid.
5. results.tsv registra tier_escalated=true para iteraciones escaladas.
6. Con MAX_TIER_ESCALATIONS_PER_SPRINT=1, segunda token_exhaustion aborta el sprint.
7. BATS suite >= 10 tests, calidad >= 80.
8. detect-token-exhaustion.sh es bash puro sin llamadas a ningun LLM.

## Out of scope

- Rotacion a proveedores externos — Savia es single-vendor por diseno.
- Modificacion de code-improvement-loop (spec separada si se necesita).
- Detector basado en LLM (anadiria latencia; regex suficiente para las senales conocidas).

## Dependencies

- Blocked by: ninguno.
- Blocks: ninguno.

## Migration path

Opt-in: AGENT_TOKEN_EXHAUSTION_RETRY=false mantiene comportamiento actual.
El parche al SKILL.md solo extiende la seccion fail-safe existente.

## Impact statement

Elimina la causa mas frecuente de fallo silencioso de overnight-sprint en tareas complejas.
Un sprint que hoy muere en iteracion 3 por tokens puede completar las 10 iteraciones planificadas
usando mid en lugar de fast, solo donde sea necesario. ROI directo: mas trabajo por sesion
autonoma. Esfuerzo: 8h. Patron validado en produccion por Santander AI Lab.
