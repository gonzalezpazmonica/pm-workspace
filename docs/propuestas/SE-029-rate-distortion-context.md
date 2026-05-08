---
id: SE-029
title: Rate-distortion-aware context compression — Savia Dual Compact v2
status: IMPLEMENTED
applied_at: "2026-04-18"
origin: bytebell rate-distortion paper + SAVIA-SUPERPOWERS research (2026-04-18)
author: Savia
related: context-compress, context-budget, context-optimize, headroom-analyze skills
---

# SE-029 — Rate-Distortion-Aware Context Compression

## Why

Shannon's rate-distortion theory es el marco correcto para compactación de contexto (bytebell.ai, 2026). Savia hoy comprime 40:1–80:1 con calidad 3.35–3.70/5.0 (D ≈ 0.30-0.33) — **en rango inaceptable para decisiones críticas**.

El paper muestra:
1. **Max lossless ratio** ≈ 8.5:1 (H(S) = log₂ vocab ≈ 17 bits/token vs 2 bits entropía semántica)
2. Beyond 8.5:1 → pérdida **garantizada**.
3. Task-aware compression supera summarization genérica.
4. Optimal compression requiere conocer queries futuras — imposible.

Savia tiene `context-compress`, `context-budget`, `context-optimize`, `headroom-analyze`, `cache-strategy`, `semantic-compact` skills. Carece de:
- Distortion metric cuantitativo
- Clasificación de turns por tarea
- Operational-point selection consciente
- Frozen core (zonas que nunca se comprimen)
- Re-state protocol post-compactación

## Scope — 5 componentes

### 1. Distortion metric (SE-029-M)

Script `scripts/context-distortion-measure.sh`:

```bash
# Mide D (distortion) comparando contexto original vs compactado
bash scripts/context-distortion-measure.sh \
  --original session.jsonl \
  --compacted session-compact.jsonl \
  --task-spec SPEC-120 \
  --judge-model claude-haiku-4-5
```

Output JSON:
```json
{
  "ratio": 38.2,
  "distortion": 0.28,
  "task_recall": 0.91,
  "coverage_task_anchors": 1.0,
  "verdict": "ACCEPTABLE"
}
```

Thresholds:
- `distortion ≤ 0.15` → HIGH quality (crítico)
- `0.15 < D ≤ 0.30` → ACCEPTABLE (general)
- `D > 0.30` → UNACCEPTABLE (re-compactar)

### 2. Task-class classifier (SE-029-C)

Clasifica cada turn en una clase de tarea:

| Clase | Ratio máximo | Frozen | Ejemplos |
|---|---|---|---|
| `decision` | 5:1 | ✓ | approvals, merge, commit |
| `spec` | 3:1 | ✓ | SPEC-NNN, AC- rules |
| `code` | 10:1 | parcial | diffs, errors, stack traces |
| `review` | 15:1 | no | code review findings |
| `context` | 25:1 | no | explicaciones, docs |
| `chitchat` | 80:1 | no | "thanks", small talk |

Implementación: `.opencode/skills/context-task-classifier/SKILL.md` + regex + heurísticas + fallback LLM-judge.

### 3. Operational point selector (SE-029-O)

Dado task-class distribution y budget disponible, elegir R(D) óptimo:

```
OPERATIONAL_POINT = argmin_R  [loss(task_recall) + α · size_penalty]
s.t.                  size(R) ≤ budget
                      D ≤ threshold_class
```

Integra con `context-budget` skill — en cada compactación emite:

```yaml
operational_point:
  target_ratio: 12:1
  expected_distortion: 0.18
  budget_remaining: 72_000 tokens
  frozen_anchors: [SPEC-120, PBI-001, decision-log.md]
  degraded_classes: [chitchat, context]
  preserved_classes: [decision, spec, code]
```

### 4. Frozen core (SE-029-F)

Zonas NUNCA comprimidas (coste asumido):

- `decision-log.md` entries ≤ 30 días
- Specs `SPEC-NNN` aprobadas referenciadas en turn actual
- Contratos de agente (handoff-as-function SPEC-121)
- Últimos 3 turns humanos raw
- AC (acceptance criteria) del sprint actual
- Errores con traceback completo (debugging)

Enforzado por `.opencode/hooks/compress-skip-frozen.sh`.

### 5. Re-state protocol (SE-029-R)

Post-compactación grande (ratio > 20:1), Savia emite automáticamente un anchor:

```markdown
## Context Re-State (post-compaction, 38:1)

**Current task**: implementing SPEC-120 spec-kit alignment
**Active spec**: docs/propuestas/SPEC-120-spec-kit-alignment.md
**Last decision**: keep additive approach (no breaking changes)
**Next step**: add bats test for compatibility
**Degraded**: chat turns 23-45 (compressed 40:1)
```

User puede corregir drift inmediatamente.

## Design — arquitectura

```
┌──────────────────────────────────────────────────────────┐
│  Savia Dual Compact v2 (SE-029)                          │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Turn ingestion                                          │
│     │                                                    │
│     ▼                                                    │
│  ┌──────────────┐                                        │
│  │ Classifier   │ (SE-029-C) → task-class per turn       │
│  └──────┬───────┘                                        │
│         │                                                │
│         ▼                                                │
│  ┌──────────────┐                                        │
│  │ Frozen check │ (SE-029-F) → NEVER compress            │
│  └──────┬───────┘                                        │
│         │                                                │
│         ▼                                                │
│  ┌──────────────┐                                        │
│  │ Operational  │ (SE-029-O) → choose R(D) per class     │
│  │ point        │                                        │
│  └──────┬───────┘                                        │
│         │                                                │
│         ▼                                                │
│  ┌──────────────┐                                        │
│  │ Compressor   │ (existing context-compress skill)      │
│  └──────┬───────┘                                        │
│         │                                                │
│         ▼                                                │
│  ┌──────────────┐                                        │
│  │ Distortion   │ (SE-029-M) → measure D post            │
│  │ measure      │                                        │
│  └──────┬───────┘                                        │
│         │                                                │
│         ▼                                                │
│    D > threshold?                                        │
│       │ yes → re-compact with lower ratio                │
│       │ no  → emit re-state anchor (SE-029-R)            │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## Acceptance Criteria

- [ ] AC-01 `scripts/context-distortion-measure.sh` implementado con 3 thresholds
- [ ] AC-02 `.opencode/skills/context-task-classifier/SKILL.md` con 6 task-classes
- [ ] AC-03 Integración con `context-budget`: emite `operational_point` YAML
- [ ] AC-04 `.opencode/hooks/compress-skip-frozen.sh` hook PreToolUse bloqueando compactación en frozen zones
- [ ] AC-05 Re-state anchor auto-generado si ratio > 20:1
- [ ] AC-06 Benchmark inicial: medir D actual vs objetivo ≤ 0.20 en 10 sesiones reales
- [ ] AC-07 Tests bats 30+ cubriendo classifier + distortion + frozen
- [ ] AC-08 Documentación: `docs/rules/domain/context-compression-protocol.md`
- [ ] AC-09 Dashboard `/context-status` actualizado con D actual + operational point

## Agent Assignment

Capa: Skills + hooks + scripts
Agente: architect + python-developer (distortion metric usa LLM-judge)

## Slicing

- Slice 1: Distortion metric standalone (SE-029-M) — 2d
- Slice 2: Task classifier (SE-029-C) — 3d
- Slice 3: Frozen core (SE-029-F) + hook — 2d
- Slice 4: Operational point selector (SE-029-O) + integración context-budget — 3d
- Slice 5: Re-state protocol (SE-029-R) + docs — 2d
- Slice 6: Benchmark inicial sobre sesiones reales + tuning thresholds — 3d

Total: ~15 días. Paralelizable en ~8 días con 2 devs.

## Feasibility Probe

Time-box: 60 min para prototipo SE-029-M (distortion measure). Riesgo principal: LLM-judge tiene su propia distortion — circularidad. Mitigación: comparar contra human eval en 20 muestras + multi-judge consensus.

## Riesgos y mitigaciones

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| LLM-judge para distortion tiene sesgo | Alta | Alto | Multi-judge (SPEC-124 pr-agent + interno) + 20-sample human ground truth |
| Classifier falla en turns híbridos (code + decision) | Media | Medio | Multi-label, pesar la clase más restrictiva |
| Frozen core explota budget | Media | Alto | Cap frozen ≤ 30% budget; si excede, promover a `decision-log.md` |
| Re-state anchor añade ruido | Baja | Bajo | Solo si ratio > 20:1, opt-out via flag |
| Benchmark D mide mal | Alta | Alto | Mejor: pair (original, query) → measure task-recall directamente |

## Métricas de éxito

Post-implementación medir en 50 sesiones reales:
- Distortion promedio D ≤ 0.20 (vs 0.30 actual)
- Task-recall ≥ 0.85
- Context wasted tokens (frozen + degraded bien) reducción ≥ 40%
- User re-state correcciones < 5% de compactaciones

## Referencias

- [bytebell.ai — Rate-Distortion Theory Applied to LLM Context Compression](https://bytebell.ai/blog/rate-distortion-theory-context-compression)
- Shannon C. "Coding Theorems for a Discrete Source with a Fidelity Criterion" (1959)
- SAVIA-SUPERPOWERS-ROADMAP.md
- Savia skills actuales: `context-compress`, `context-budget`, `context-optimize`, `headroom-analyze`, `cache-strategy`, `semantic-compact`
