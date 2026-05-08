---
id: SE-028
title: oumi integration — data synth + eval + distillation for SE-027 SLM pipeline
status: APPROVED
approved_at: "2026-04-19"
approved_reason: "Strategic SLM pipeline — data synthesis scaffolding priority"
priority: P1-Tier1
origin: Savia autonomous roadmap — oumi-ai/oumi research (2026-04-17)
author: Savia
related: [SPEC-SE-027, SPEC-023, SPEC-080, SE-042]
---

# SE-028 — oumi Integration (complement to SE-027)

## Why

[oumi-ai/oumi](https://github.com/oumi-ai/oumi) es una plataforma OSS (Apache-2.0) con $10M seed, 9.2k ⭐, lanzada por ex-Google/Microsoft/Apple con 13 universidades colaboradoras. Provee pipeline unificado: data → train → eval → infer → deploy con YAML configs portables laptop↔multi-nodo.

Nuestro SE-027 actual (Unsloth + Ollama) **gana en velocidad** consumer GPU (2-3x más rápido que oumi QLoRA — oumi no integra Triton kernels Unsloth). Pero tiene huecos reales:

1. **Sin synthetic data generation** por proyecto
2. **Sin eval suite estructurada** (hoy manual)
3. **Sin pipeline distillation** frontier→3-7B
4. **Sin YAML recipes** (configs ad-hoc)

oumi resuelve los 4 huecos sin competir con Unsloth como training backend.

## Scope — adopción selectiva

**Adoptar** (4 componentes):

| # | Componente oumi | Qué resuelve | Effort |
|---|---|---|---|
| 1 | `oumi synth` | Generación sintética datos per-proyecto | 2d |
| 2 | `oumi evaluate` + code-judges | Eval suite para SLMs de proyecto | 3d |
| 3 | GKD distillation notebook | Distillar frontier → SLM 3-7B | 5d |
| 4 | YAML recipe pattern | Estandarizar configs SE-027 | 1d |

**No adoptar**:
- oumi como training backend (redundante con Unsloth, QLoRA 2-3x más lento)
- Deploy stack oumi (Fireworks/OpenRouter/SkyPilot/Nebius) — viola zero-egress
- `oumi tune` hyperparameter search — overkill para per-project SLMs

## Design

### Arquitectura post-integración

```
┌─────────────────────────────────────────────────────┐
│         pm-workspace SLM pipeline (SE-027 + SE-028) │
├─────────────────────────────────────────────────────┤
│  DATA          │  oumi synth (proj code corpus)     │
│                │  + manual curation                  │
├────────────────┼─────────────────────────────────────┤
│  TRAINING      │  Unsloth (QLoRA, 4-bit)            │  ← SE-027
│                │  Single 24GB consumer GPU           │
├────────────────┼─────────────────────────────────────┤
│  EVAL          │  oumi evaluate + code-LLM-judges    │
│                │  Project-specific benchmarks        │
├────────────────┼─────────────────────────────────────┤
│  DISTILL       │  oumi GKD: frontier→SLM 3-7B        │
│                │  (experimental, opt-in)             │
├────────────────┼─────────────────────────────────────┤
│  EXPORT        │  Unsloth→GGUF→Ollama               │  ← SE-027
│                │  Zero-egress deploy local           │
├────────────────┼─────────────────────────────────────┤
│  CONFIG        │  YAML recipes (oumi-compatible)     │
└─────────────────────────────────────────────────────┘
```

### YAML recipes structure

```yaml
# projects/{name}/.slm/recipes/fine-tune.yaml
model:
  base_model: "unsloth/llama-4-8b-Instruct-bnb-4bit"
  max_seq_length: 4096

data:
  train_set: "projects/{name}/.slm/data/synthesized.jsonl"
  eval_set: "projects/{name}/.slm/data/eval.jsonl"

training:
  backend: "unsloth"          # our choice, not oumi
  method: "qlora"
  r: 16
  alpha: 32
  epochs: 3
  batch_size: 8
  learning_rate: 2e-4

eval:
  backend: "oumi"             # oumi for eval
  benchmarks:
    - "code_humaneval_project"
    - "project_conventions_judge"

export:
  format: "gguf"
  deploy: "ollama"             # local, zero-egress
```

## Acceptance Criteria

- [ ] AC-01 `scripts/slm-synth.sh` wrapper sobre `oumi synth` con inputs per-proyecto
- [ ] AC-02 `scripts/slm-eval.sh` wrapper sobre `oumi evaluate` con judges custom
- [ ] AC-03 `scripts/slm-distill.sh` wrapper para GKD (opt-in flag)
- [ ] AC-04 `projects/{name}/.slm/recipes/*.yaml` template (fine-tune + eval + export)
- [ ] AC-05 `docs/rules/domain/slm-pipeline-protocol.md` documenta SE-027 + SE-028 stack
- [ ] AC-06 `.opencode/skills/savia-dual/SKILL.md` actualizado con nueva capability
- [ ] AC-07 oumi v0.7 pinned en `pyproject.toml` / requirements.lock del skill
- [ ] AC-08 Test bats `tests/slm-pipeline.bats` valida wrappers (mock oumi CLI)
- [ ] AC-09 CHANGELOG entry
- [ ] AC-10 Compatibility test: full pipeline (synth → unsloth train → oumi eval → gguf export) en project fixture

## Agent Assignment

Capa: Skills + scripts + infrastructure
Agente: python-developer + infrastructure-agent (oumi CLI install + env setup)

## Slicing

- Slice 1: YAML recipe template + docs (AC-04, AC-05, AC-06) — foundation
- Slice 2: `slm-synth.sh` + `slm-eval.sh` wrappers (AC-01, AC-02)
- Slice 3: `slm-distill.sh` + tests (AC-03, AC-08)
- Slice 4: Compatibility test E2E + CHANGELOG (AC-09, AC-10)

## Feasibility Probe

Time-box: 90 min para slice 1 (recipe + docs). Riesgo principal: oumi pin v0.7 puede tener conflicto con Unsloth deps (ambos usan torch). Mitigación: entornos Python separados (`.slm-train/` Unsloth, `.slm-eval/` oumi).

## Riesgos y mitigaciones

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| oumi tier comercial Mar 2026 → regresión OSS | Media | Alto | Pinear v0.7, monitor quarterly, fallback al branch OSS-only |
| Conflicto deps torch oumi ↔ Unsloth | Alta | Medio | Entornos Python aislados (`.slm-train/`, `.slm-eval/`) |
| GKD distillation lento en consumer GPU | Alta | Medio | Marcar GKD como experimental, opt-in |
| Config YAML divergencia oumi ↔ nuestros wrappers | Media | Medio | Schema validator + tests fixture |
| Coste cloud si alguien usa deploy oumi por error | Baja | Alto | Wrappers bloquean targets != ollama/local |

## Dependencies

- SE-027 activo y funcional (Unsloth + Ollama)
- Python 3.11+ (oumi requiere 3.12+ recommend)
- ~3GB libres para oumi install

## Referencias

- [oumi-ai/oumi](https://github.com/oumi-ai/oumi) — repo
- [Oumi v0.7 release notes](https://github.com/oumi-ai/oumi/releases)
- [Oumi Distillation Notebook](https://github.com/oumi-ai/oumi/blob/main/notebooks/Oumi%20-%20Distill%20a%20Large%20Model.ipynb)
- [Oumi docs](https://www.oumi.ai/docs)
- SE-027 (pipeline Unsloth + Ollama existente)
- SAVIA-SUPERPOWERS-ROADMAP.md
