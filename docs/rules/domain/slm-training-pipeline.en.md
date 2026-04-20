# SLM Training Pipeline — Software Scaffolding

> **Priority**: P1-Tier1 · **Status**: APPROVED (2026-04-19)
> Unified entry point for all SLM-related specs. GPU execution deferred until hardware is available; **software scaffolding is ready now**.

Complete pipeline for training Small Language Models (SLMs) for Savia, from data preparation to Ollama deployment. Coordinates 5 approved specs:

| Spec | Role |
|---|---|
| **SPEC-SE-027** | Strategic — SLM training pipeline (enterprise-grade) |
| **SPEC-023** | Savia LLM Trainer — local context brain |
| **SPEC-080** | Unsloth toolchain — specialized training |
| **SE-028** | oumi integration — data synthesis + eval + distillation |
| **SE-042** | Voice/persona training — chat-to-SFT (WeClone pattern) |

## 1. Pipeline architecture (5 phases)

```
[1] DATASET PREP     — JSONL → Unsloth SFT format (SE-042)
[2] DATA SYNTHESIS   — oumi strategies (Q&A, paraphrasing, distillation) (SE-028)
[3] TRAIN CONFIG     — slm-train-config.sh → YAML (base_model, LoRA r=16, 4-bit, flash-attn)
[4] GPU TRAINING     — python train.py (CUDA required)  ← DEFERRED
[5] EXPORT & EVAL    — slm-export-gguf.sh → Ollama GGUF + eval report
```

## 2. Scaffolding available NOW (no GPU required)

| Script | Phase | Purpose |
|---|---|---|
| `slm-project-init.sh` | 0 | Bootstrap canonical project layout |
| `slm-data-collect.sh` | 1 | Harvest training data from specs/agents/skills |
| `slm-dataset-prep.sh` | 1 | JSONL → Unsloth SFT format |
| `slm-dataset-validate.sh` | 1 | Pre-training validator (PII scan, dedup, stats) |
| `slm-synth-recipe.sh` | 2 | Emit oumi synthesis recipe YAML |
| `slm-train-config.sh` | 3 | Generate Unsloth/TRL YAML config |
| `slm-export-gguf.sh` | 5 | llama.cpp conversion (merge LoRA + quantize) |
| `slm-modelfile-gen.sh` | 5 | Ollama Modelfile generator (5 personas) |
| `slm-eval-harness-setup.sh` | 5 | Prepare eval harness config |
| `slm-eval-compare.sh` | 5 | A/B comparator (PROMOTE/ROLLBACK verdict) |
| `slm-registry.sh` | meta | Track trained models (single-deployed invariant) |
| `slm-deploy.sh` | meta | Orchestrator: export + modelfile + register |
| `slm-pipeline-validate.sh` | meta | Validate complete SLM project layout |

GPU-only (not executable now): `slm-train.py` (Unsloth fine-tuning), `slm-eval-run.py` (LLM-judge).

## 3. Canonical directory layout

```
projects/{slm-name}/
├── config.yaml              # slm-train-config.sh output
├── datasets/{raw,processed,synthetic}/
├── checkpoints/             # gitignored
├── adapters/                # LoRA weights (gitignored)
├── gguf/                    # Final export (gitignored)
├── eval/{harness.yaml,results/}
└── README.md                # Auto-generated
```

## 4. Recommended base models (CPU-trainable tier)

| Model | Params | Unsloth 4-bit | Use case |
|---|---|---|---|
| Qwen2.5-0.5B | 0.5B | 2 GB | Short routines |
| Llama-3.2-1B | 1B | 4 GB | Savia context brain (SPEC-023) |
| Llama-3.2-3B | 3B | 8 GB | Complex specialized agents |
| Qwen2.5-3B | 3B | 8 GB | Multilingual ES+EN |

## 5. When to use each spec

- **SPEC-023** — context compression / decision-log recall.
- **SPEC-080** — Unsloth framework (4-bit QLoRA, speed).
- **SE-028** — data synthesis via oumi (Q&A, paraphrasing).
- **SE-042** — Savia persona fine-tune (chat-to-SFT from WeClone).
- **SPEC-SE-027** — enterprise deployment (fleet, observability, rollback).

## 6. Sovereignty & security

- **Zero egress** — entire pipeline runs locally.
- **Own hardware** — training on tenant's own GPU.
- **Audit trail** — each phase emits input+output+config hash.
- **GDPR** — `slm-dataset-prep.sh --pii-scrub` mandatory if PII present.
- **Model cards** — data sources, eval results, limitations.

## 7. Savia Dual integration

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

| Phase | Requires | Status |
|---|---|---|
| Scaffolding (datasets, config, validators) | nothing | **IMPLEMENTABLE NOW** |
| oumi data synthesis | Python + disk | IMPLEMENTABLE |
| GPU training | CUDA GPU | **DEFERRED** |
| Eval + deploy | Ollama + eval set | IMPLEMENTABLE |

## 9. References

- SPEC-SE-027: `docs/propuestas/savia-enterprise/SPEC-SE-027-slm-training.md`
- SPEC-023/080: `docs/propuestas/SPEC-023-*.md`, `SPEC-080-*.md`
- SE-028/042: `docs/propuestas/SE-028-*.md`, `SE-042-*.md`
- Unsloth: github.com/unslothai/unsloth · oumi: github.com/oumi-ai/oumi · WeClone: github.com/xming521/WeClone
- Spanish: `docs/rules/domain/slm-training-pipeline.md`
