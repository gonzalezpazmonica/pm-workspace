# SLM Training Pipeline — Software Scaffolding

> **Priority**: P1-Tier1 · **Status**: APPROVED (2026-04-19)
> Unified entry point for all SLM-related specs. GPU execution deferred
> until hardware available; **software scaffolding ready now**.

Pipeline completo de entrenamiento de Small Language Models (SLMs) para
Savia, desde preparación de datos hasta despliegue en Ollama. Este
documento coordina 5 specs aprobados:

| Spec | Rol |
|---|---|
| **SPEC-SE-027** | Strategic — SLM training pipeline (enterprise-grade) |
| **SPEC-023** | Savia LLM Trainer — context brain local |
| **SPEC-080** | Unsloth toolchain — entrenamiento especializado |
| **SE-028** | oumi integration — data synthesis + eval + distillation |
| **SE-042** | Voice/persona training — chat-to-SFT (pattern WeClone) |

## 1. Arquitectura del pipeline (5 fases)

```
┌────────────────────────────────────────────────────────────────┐
│                 SLM TRAINING PIPELINE                           │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [Fase 1] DATASET PREP                                          │
│     JSONL conversations / memory / engrams                      │
│     ↓  slm-dataset-prep.sh  (SE-042 pattern)                    │
│     Unsloth SFT format (instruction / input / output triples)   │
│                                                                  │
│  [Fase 2] DATA SYNTHESIS & FILTERING  (SE-028)                  │
│     oumi synthesis strategies (Q&A, paraphrasing, distillation) │
│     ↓                                                            │
│     Quality-filtered training set                               │
│                                                                  │
│  [Fase 3] TRAIN CONFIG GENERATION                               │
│     slm-train-config.sh → YAML config                           │
│     - base_model (Llama-3.2-1B / 3B / Qwen2.5-0.5B / etc)       │
│     - LoRA params (r=16, alpha=16, dropout=0.1)                 │
│     - Unsloth optimizations (4-bit, flash-attention)            │
│                                                                  │
│  [Fase 4] ⚙  GPU TRAINING  ← DEFERRED (sin hardware hoy)        │
│     python train.py --config <yaml>   (requires CUDA GPU)       │
│     ↓ outputs: adapter weights (LoRA), training metrics         │
│                                                                  │
│  [Fase 5] EXPORT & EVAL                                         │
│     slm-export-gguf.sh   (runs on CPU, merges LoRA + base)      │
│     ↓                                                            │
│     Ollama-compatible GGUF model + eval report                  │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

## 2. Scaffolding disponible AHORA (sin GPU)

Scripts que operan sin hardware especializado:

| Script | Fase | Función |
|---|---|---|
| `scripts/slm-dataset-prep.sh` | 1 | Convierte JSONL conversations → Unsloth SFT format |
| `scripts/slm-train-config.sh` | 3 | Genera YAML de config Unsloth/TRL con params validados |
| `scripts/slm-pipeline-validate.sh` | meta | Valida estructura de proyecto SLM completa |
| `scripts/slm-eval-harness-setup.sh` | 5 | Prepara eval harness config (no ejecuta eval) |

Scripts que REQUIEREN GPU (no ejecutables ahora):
- `python scripts/slm-train.py` — fine-tuning real con Unsloth
- Evaluación LLM-judge sobre el adapter

## 3. Directorio layout estandarizado

```
projects/{slm-name}/
├── config.yaml              # slm-train-config.sh output
├── datasets/
│   ├── raw/                 # JSONL originales
│   ├── processed/           # tras slm-dataset-prep.sh
│   └── synthetic/           # oumi synthesis output (Fase 2)
├── checkpoints/             # GPU training output (gitignored)
├── adapters/                # LoRA weights (gitignored, too big)
├── gguf/                    # export final (gitignored)
├── eval/
│   ├── harness.yaml         # eval-harness-setup output
│   └── results/             # post-train eval reports
└── README.md                # auto-generado en init
```

## 4. Modelos base recomendados (CPU-trainable tier)

| Modelo | Params | Unsloth 4-bit | Time/epoch (RTX 3060) | Use case |
|---|---|---|---|---|
| Qwen2.5-0.5B | 0.5B | 2 GB | ~15 min | Rutinas cortas, tasks simples |
| Llama-3.2-1B | 1B | 4 GB | ~30 min | Savia context brain (SPEC-023) |
| Llama-3.2-3B | 3B | 8 GB | ~90 min | Agentes especializados complejos |
| Qwen2.5-3B | 3B | 8 GB | ~90 min | Multilingual ES+EN |

## 5. Cuándo usar cada spec

- **SPEC-023** (Savia LLM Trainer) — entrenas un modelo que asiste compresión de contexto / decisión-log recall.
- **SPEC-080** (Unsloth) — eliges Unsloth como framework por 4-bit QLoRA + speed.
- **SE-028** (oumi) — necesitas sintetizar más data (Q&A pairs, paraphrasing) sobre JSONL pequeño.
- **SE-042** (Voice) — fine-tune con persona Savia: chat-to-SFT patter de WeClone.
- **SPEC-SE-027** — enterprise deploy del modelo entrenado (fleet, observability, rollback).

## 6. Soberanía y seguridad

- **Zero egress** — todo el pipeline corre local. Ningún dato cruza a APIs de terceros.
- **Hardware propio** — training solo en GPU propia del tenant (cloud opt-in).
- **Audit trail** — cada fase emite hash de input + output + config para reproducibilidad.
- **GDPR** — si el training set contiene PII, `slm-dataset-prep.sh --pii-scrub` obligatorio.
- **Model cards** — cada modelo exportado incluye model card con data sources, eval results, limitaciones.

## 7. Savia Dual integration

El modelo entrenado se registra en `savia-dual` skill como provider local:

```yaml
# .claude/config/savia-dual.yaml
providers:
  - name: "savia-context-brain-v1"
    type: "ollama"
    model: "savia-context-1b:latest"
    use_for: [context-compress, memory-recall, engram-scoring]
    fallback_to: "claude-haiku-4-5"
```

## 8. Roadmap de fases

| Fase | Requiere | Estado hoy |
|---|---|---|
| Scaffolding software (datasets, config, validators) | ninguno | **IMPLEMENTABLE AHORA** ← foco Slice 1 |
| Data synthesis oumi | Python + disk | IMPLEMENTABLE (scripts no-GPU) |
| GPU training | CUDA GPU propia | **DEFERRED** hasta hardware |
| Eval + deploy | Ollama + tiny-eval set | IMPLEMENTABLE con modelo pre-existente |

## 9. Referencias

- SPEC-SE-027: `docs/propuestas/savia-enterprise/SPEC-SE-027-slm-training.md`
- SPEC-023: `docs/propuestas/SPEC-023-savia-llm-trainer.md`
- SPEC-080: `docs/propuestas/SPEC-080-custom-llm-training-unsloth.md`
- SE-028: `docs/propuestas/SE-028-oumi-integration.md`
- SE-042: `docs/propuestas/SE-042-savia-voice-training-pipeline.md`
- Unsloth: https://github.com/unslothai/unsloth
- oumi: https://github.com/oumi-ai/oumi
- WeClone (patrón): https://github.com/xming521/WeClone
