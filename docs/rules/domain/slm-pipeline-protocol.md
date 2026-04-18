# SLM Pipeline Protocol — SE-028

> Per-project Small Language Model pipeline: training (Unsloth), evaluation (oumi), deployment (Ollama). Zero-egress end-to-end.

## Arquitectura

```
data ─▶ training ─▶ export ─▶ deploy
 │        │          │         │
 oumi    Unsloth    GGUF       Ollama
 synth   QLoRA     convert    (local only)
 │
 oumi
 evaluate
```

## Componentes

| Stage | Tool | Script | Frozen? |
|---|---|---|---|
| Data synth | [oumi synth](https://github.com/oumi-ai/oumi) | `scripts/slm-synth.sh` | No |
| Training | [Unsloth](https://github.com/unslothai/unsloth) | `scripts/slm-train.sh` (SE-027) | Yes — our canonical |
| Eval | [oumi evaluate](https://github.com/oumi-ai/oumi) | `scripts/slm-eval.sh` | No |
| Distill | oumi GKD notebook | `scripts/slm-distill.sh` | Opt-in experimental |
| Export | Unsloth → GGUF | native | Yes |
| Deploy | Ollama | `ollama create` | Yes — zero-egress |

## YAML recipe template

Cada proyecto tiene su recipe en `projects/{name}/.slm/recipes/fine-tune.yaml`:

```yaml
# projects/{name}/.slm/recipes/fine-tune.yaml
model:
  base_model: "unsloth/llama-4-8b-Instruct-bnb-4bit"
  max_seq_length: 4096

data:
  synth:
    enabled: true
    prompts_file: "projects/{name}/.slm/data/seed-prompts.jsonl"
    n_samples: 5000
    judge_model: "claude-haiku-4-5"
  train_set: "projects/{name}/.slm/data/train.jsonl"
  eval_set: "projects/{name}/.slm/data/eval.jsonl"

training:
  backend: "unsloth"          # our choice
  method: "qlora"
  r: 16
  alpha: 32
  epochs: 3
  batch_size: 8
  learning_rate: 2e-4
  max_grad_norm: 0.3

eval:
  backend: "oumi"             # eval complementa training
  benchmarks:
    - "code_humaneval_project"
    - "project_conventions_judge"
  thresholds:
    pass_at_1: 0.65
    groundedness: 0.9

export:
  format: "gguf"
  quantization: "q4_k_m"
  deploy: "ollama"
  tag: "savia-{project}-slm:latest"
```

## Zero-egress guard

Wrappers rechazan targets cloud:

```bash
# ALLOWED
export: {format: gguf, deploy: ollama}

# REJECTED (zero-egress violation)
export: {deploy: fireworks|openrouter|bedrock|anthropic}
```

## Rollout

1. **Slice 1** (actual): synth wrapper + YAML recipe + protocol doc
2. **Slice 2**: eval wrapper + benchmark integration
3. **Slice 3**: distill notebook (opt-in)
4. **Slice 4**: E2E compatibility test on fixture project

## Isolation (Python envs)

oumi y Unsloth tienen conflictos deps (torch versions). Aislar:

```
.slm-train/  ← Unsloth env (torch 2.9)
.slm-eval/   ← oumi env    (torch 2.9, different pins)
```

Wrappers activan el env correspondiente.

## Referencias

- SE-028 — `docs/propuestas/SE-028-oumi-integration.md`
- SE-027 — pipeline Unsloth+Ollama existente (canónico training)
- [oumi-ai/oumi v0.7](https://github.com/oumi-ai/oumi) — pinned version
