# SLM Training Pipeline — Software Scaffolding

> **Priority**: P1-Tier1 · **Status**: APPROVED (2026-04-19)
> Unified entry point for all SLM-related specs. GPU execution deferred
> until hardware is available; **software scaffolding is ready now**.

Complete pipeline for training Small Language Models (SLMs) for Savia,
from data preparation to deployment on Ollama. This document coordinates
5 approved specs:

| Spec | Role |
|---|---|
| **SPEC-SE-027** | Strategic — SLM training pipeline (enterprise-grade) |
| **SPEC-023** | Savia LLM Trainer — local context brain |
| **SPEC-080** | Unsloth toolchain — specialized training |
| **SE-028** | oumi integration — data synthesis + eval + distillation |
| **SE-042** | Voice/persona training — chat-to-SFT (WeClone pattern) |

## 1. Pipeline architecture (5 phases)

```
┌────────────────────────────────────────────────────────────────┐
│                 SLM TRAINING PIPELINE                           │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [Phase 1] DATASET PREP                                         │
│     JSONL conversations / memory / engrams                      │
│     ↓  slm-dataset-prep.sh  (SE-042 pattern)                    │
│     Unsloth SFT format (instruction / input / output triples)   │
│                                                                  │
│  [Phase 2] DATA SYNTHESIS & FILTERING  (SE-028)                 │
│     oumi synthesis strategies (Q&A, paraphrasing, distillation) │
│     ↓                                                            │
│     Quality-filtered training set                               │
│                                                                  │
│  [Phase 3] TRAIN CONFIG GENERATION                              │
│     slm-train-config.sh → YAML config                           │
│     - base_model (Llama-3.2-1B / 3B / Qwen2.5-0.5B / etc)       │
│     - LoRA params (r=16, alpha=16, dropout=0.1)                 │
│     - Unsloth optimizations (4-bit, flash-attention)            │
│                                                                  │
│  [Phase 4] ⚙  GPU TRAINING  ← DEFERRED (no hardware today)      │
│     python train.py --config <yaml>   (requires CUDA GPU)       │
│     ↓ outputs: adapter weights (LoRA), training metrics         │
│                                                                  │
│  [Phase 5] EXPORT & EVAL                                        │
│     slm-export-gguf.sh   (runs on CPU, merges LoRA + base)      │
│     ↓                                                            │
│     Ollama-compatible GGUF model + eval report                  │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

## 2. Scaffolding available NOW (no GPU required)

Scripts that operate without specialized hardware:

| Script | Phase | Purpose |
|---|---|---|
| `scripts/slm-project-init.sh` | 0 | Bootstrap canonical project layout |
| `scripts/slm-data-collect.sh` | 1 | Harvest training data from workspace specs/agents/skills |
| `scripts/slm-dataset-prep.sh` | 1 | Convert JSONL conversations → Unsloth SFT format |
| `scripts/slm-dataset-validate.sh` | 1 | Pre-training validator (PII scan, dedup, length stats) |
| `scripts/slm-synth-recipe.sh` | 2 | Emit oumi synthesis recipe YAML |
| `scripts/slm-train-config.sh` | 3 | Generate Unsloth/TRL YAML config with validated params |
| `scripts/slm-export-gguf.sh` | 5 | llama.cpp conversion recipe (merge LoRA + quantize) |
| `scripts/slm-modelfile-gen.sh` | 5 | Ollama Modelfile generator (5 personas) |
| `scripts/slm-eval-harness-setup.sh` | 5 | Prepare eval harness config (doesn't run eval) |
| `scripts/slm-eval-compare.sh` | 5 | A/B eval comparator (PROMOTE/ROLLBACK verdict) |
| `scripts/slm-registry.sh` | meta | Track trained models (manifest.json, single-deployed invariant) |
| `scripts/slm-deploy.sh` | meta | Orchestrator: export + modelfile + register in 1 call |
| `scripts/slm-pipeline-validate.sh` | meta | Validate complete SLM project layout |

Scripts that REQUIRE GPU (not executable now):
- `python scripts/slm-train.py` — real fine-tuning with Unsloth
- `python scripts/slm-eval-run.py` — LLM-judge eval over adapter

## 3. Canonical directory layout

```
projects/{slm-name}/
├── config.yaml              # slm-train-config.sh output
├── datasets/
│   ├── raw/                 # Original JSONL files
│   ├── processed/           # After slm-dataset-prep.sh
│   └── synthetic/           # oumi synthesis output (Phase 2)
├── checkpoints/             # GPU training output (gitignored)
├── adapters/                # LoRA weights (gitignored, too large)
├── gguf/                    # Final export (gitignored)
├── eval/
│   ├── harness.yaml         # eval-harness-setup output
│   └── results/             # Post-train eval reports
└── README.md                # Auto-generated on init
```

## 4. Recommended base models (CPU-trainable tier)

| Model | Params | Unsloth 4-bit | Time/epoch (RTX 3060) | Use case |
|---|---|---|---|---|
| Qwen2.5-0.5B | 0.5B | 2 GB | ~15 min | Short routines, simple tasks |
| Llama-3.2-1B | 1B | 4 GB | ~30 min | Savia context brain (SPEC-023) |
| Llama-3.2-3B | 3B | 8 GB | ~90 min | Complex specialized agents |
| Qwen2.5-3B | 3B | 8 GB | ~90 min | Multilingual ES+EN |

## 5. When to use each spec

- **SPEC-023** (Savia LLM Trainer) — train a model that assists with context compression / decision-log recall.
- **SPEC-080** (Unsloth) — choose Unsloth as framework for 4-bit QLoRA + speed.
- **SE-028** (oumi) — synthesize more data (Q&A pairs, paraphrasing) over small JSONL.
- **SE-042** (Voice) — fine-tune with Savia persona: chat-to-SFT pattern from WeClone.
- **SPEC-SE-027** — enterprise deployment of trained model (fleet, observability, rollback).

## 6. Sovereignty & security

- **Zero egress** — entire pipeline runs locally. No data crosses to third-party APIs.
- **Own hardware** — training only on tenant's own GPU (cloud opt-in).
- **Audit trail** — each phase emits hash of input + output + config for reproducibility.
- **GDPR** — if training set contains PII, `slm-dataset-prep.sh --pii-scrub` is mandatory.
- **Model cards** — each exported model includes model card with data sources, eval results, limitations.

## 7. Savia Dual integration

The trained model registers in `savia-dual` skill as local provider:

```yaml
# .claude/config/savia-dual.yaml
providers:
  - name: "savia-context-brain-v1"
    type: "ollama"
    model: "savia-context-1b:latest"
    use_for: [context-compress, memory-recall, engram-scoring]
    fallback_to: "claude-haiku-4-5"
```

## 8. Phase roadmap

| Phase | Requires | Status today |
|---|---|---|
| Scaffolding software (datasets, config, validators) | nothing | **IMPLEMENTABLE NOW** ← Slice 1 focus |
| oumi data synthesis | Python + disk | IMPLEMENTABLE (no-GPU scripts) |
| GPU training | Own CUDA GPU | **DEFERRED** until hardware |
| Eval + deploy | Ollama + tiny-eval set | IMPLEMENTABLE with pre-existing model |

## 9. References

- SPEC-SE-027: `docs/propuestas/savia-enterprise/SPEC-SE-027-slm-training.md`
- SPEC-023: `docs/propuestas/SPEC-023-savia-llm-trainer.md`
- SPEC-080: `docs/propuestas/SPEC-080-custom-llm-training-unsloth.md`
- SE-028: `docs/propuestas/SE-028-oumi-integration.md`
- SE-042: `docs/propuestas/SE-042-savia-voice-training-pipeline.md`
- Unsloth: https://github.com/unslothai/unsloth
- oumi: https://github.com/oumi-ai/oumi
- WeClone (pattern): https://github.com/xming521/WeClone

## 10. Related

- Spanish version: `docs/rules/domain/slm-training-pipeline.md`
