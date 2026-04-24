---
id: SE-030
title: GraphRAG Quality Gates — receipts + 12 thresholds + seam tests
status: PROPOSED
origin: bytebell.ai blog series (Dic '25 – Ene '26)
author: Savia
related: SE-028, SE-029, knowledge-graph, eval-run, verify-full
priority: baja
---

# SE-030 — GraphRAG Quality Gates

## Why

bytebell.ai publicó en Dic'25–Ene'26 una serie de 7 artículos sobre evaluación estructurada de sistemas GraphRAG. Extraemos 3 ideas con fit directo en Savia:

1. **Receipts-first governance** — sub-4% hallucination con citas file:line obligatorias (vs 3-20% sin receipts).
2. **12 thresholds de calidad** (NDCG@10, Recall@20, MRR, Cross-Repo Precision, Coherence, Groundedness, Hallucination, Attribution).
3. **Seam tests** — measure delta al quitar capa graph (NDCG cae -0.12, pass-rate -0.06). No basta con tests unitarios por capa.

Savia hoy:
- ❌ Agentes emiten contexto sin receipts sistemáticos
- ❌ `eval-run` no tiene thresholds cuantitativos del paper
- ❌ Court juzga resultado, no retrieval
- ❌ Sin ablation/seam tests en `verify-full`

Adopción de patrón, no de plataforma (consistente con SE-028 y SAVIA-SUPERPOWERS).

## Scope — 4 componentes

### 1. Receipts protocol (SE-030-R)

Contrato: **toda afirmación de un agente sobre código/spec/decisión debe incluir receipt**.

Formato canónico:

```yaml
claim: "PatientService ya implementa la interfaz IEntity"
receipts:
  - file: src/Application/Patients/PatientService.cs
    line: 23
    sha: abc123de  # commit SHA short
  - spec: SPEC-120#AC-03
  - decision: decision-log.md#2026-04-15-patient-service
```

Sin receipt → el claim se marca como `[UNVERIFIED]` automáticamente y NO se propaga al Court como evidencia.

Validator: `scripts/context-receipts-validate.sh` — parsea outputs de agentes y reporta claims sin receipt.

### 2. 12 quality thresholds (SE-030-T)

Definidos en `docs/rules/domain/graphrag-quality-gates.md`:

**Retrieval layer**:
- NDCG@10 ≥ 0.75
- Recall@20 ≥ 0.85
- MRR ≥ 0.6
- Cross-Repo Precision ≥ 0.7

**Reasoning layer**:
- Context Coherence ≥ 0.9
- Relevance ≥ 0.8
- Completeness ≥ 0.85

**Generation layer**:
- Groundedness ≥ 0.9
- Hallucination ≤ 0.1
- Attribution Accuracy ≥ 0.95
- Factual Accuracy ≥ 0.9
- Coherence ≥ 0.85

Integra en `eval-run` — fallar cualquiera de los 12 bloquea el sprint close.

### 3. Source hierarchy (SE-030-H)

Prioridad autoritativa en `memory-importance` scoring:

```
code          weight 1.0   (git tracked .cs/.ts/.py)
tests         weight 0.9   (*.test.*, *.spec.*)
approved-spec weight 0.85  (docs/propuestas/SPEC-*.md status=APPROVED)
docs          weight 0.7   (docs/**/*.md)
commit-msg    weight 0.6
pr-review     weight 0.5
chat-user     weight 0.4   (human turns)
chat-agent    weight 0.2   (agent turns — circular)
external-web  weight 0.3   (WebFetch content)
```

Aplicar al re-rankear candidatos en `knowledge-prime`, `memory-recall`, `entity-recall`.

### 4. Seam / ablation tests (SE-030-A)

En `verify-full` y `eval-run`, añadir runs de ablación:

```bash
# Full pipeline
./scripts/eval-run.sh --suite graphrag-full

# Ablation: quita capa graph
./scripts/eval-run.sh --suite graphrag-full --ablate graph

# Expected delta: NDCG drops 0.10+, pass@1 drops 0.05+
```

Si el delta de ablación es < 0.05, la capa "no aporta" — warning para deprecar/simplificar.

## Design

### Receipts validator

```bash
$ bash scripts/context-receipts-validate.sh --input agent-output.md

PASS | 8 claims with valid receipts
WARN | 2 claims unverified (no receipt)
  - line 42: "the handler already handles concurrent writes"
  - line 67: "tests cover the edge case"
FAIL | 0 invalid receipts (file not found / bad SHA)

Exit 0 if no FAIL, 1 if any WARN, 2 if any FAIL
```

### Source hierarchy applied

```yaml
# memory-importance scoring adapted
score(engram) = base_score * source_weight * recency_decay
```

Donde `source_weight` viene de la tabla SE-030-H.

## Acceptance Criteria

- [ ] AC-01 `docs/rules/domain/receipts-protocol.md` creado con formato canónico
- [ ] AC-02 `scripts/context-receipts-validate.sh` implementado (parse + check file:line + SHA)
- [ ] AC-03 `docs/rules/domain/graphrag-quality-gates.md` creado con 12 thresholds
- [ ] AC-04 `scripts/memory-importance.sh` actualizado con source_weight table
- [ ] AC-05 `eval-run` acepta `--ablate {layer}` para seam tests
- [ ] AC-06 Test bats para receipts-validate (15+ tests)
- [ ] AC-07 Test bats para quality-gates parser (10+ tests)
- [ ] AC-08 Integración con Court: `pr-agent-judge` y `correctness-judge` consultan thresholds
- [ ] AC-09 CHANGELOG entry

## Agent Assignment

Capa: Skills + scripts + protocols
Agente: architect + python-developer

## Slicing

- Slice 1: Receipts protocol doc + validator script + tests (MVP)
- Slice 2: Quality thresholds doc + parser
- Slice 3: Source hierarchy integration en memory-importance
- Slice 4: Ablation runs en eval-run

## Feasibility Probe

Time-box: 45 min slice 1. Riesgo: LLM agents ignoran formato receipts. Mitigación: validator emite WARN (no FAIL) al principio → recolección de métricas → eventualmente hard gate.

## Riesgos y mitigaciones

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Agentes no siguen formato receipts | Alta | Medio | Rollout gradual: WARN → FAIL en 2 sprints |
| Thresholds demasiado estrictos inicialmente | Media | Alto | Baseline measurement primero, calibrar |
| Overhead de validación receipts lento | Baja | Bajo | Validator <100ms en 1000 claims |
| Source hierarchy sesga contra chat útil | Media | Medio | Min weight 0.2 garantiza presencia |
| Ablation tests requieren baseline extenso | Alta | Medio | Comenzar con 1 ablación (graph layer) |

## Métricas de éxito

Post-implementación en 4 sprints:
- Hallucination rate: objetivo ≤ 0.04 (bytebell benchmark)
- Attribution accuracy: ≥ 0.95
- Receipts coverage: ≥ 90% claims con receipt válido
- Ablation delta graph layer: ≥ 0.10 NDCG (confirma valor de la capa)

## Referencias

- [bytebell — Simple Graph RAG](https://bytebell.ai/blog) Dic '25
- [bytebell — Three-Layer GraphRAG Eval Framework](https://bytebell.ai/blog) Dic '25
- [bytebell — Sub-4% Hallucination Copilot](https://bytebell.ai/blog) Oct '25
- [bytebell — End-to-End Stress Test](https://bytebell.ai/blog) Ene '26
- [bytebell — Context Graph Is Misunderstood](https://bytebell.ai/blog) Ene '26
- SE-028, SE-029 — specs complementarios
