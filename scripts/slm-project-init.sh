#!/usr/bin/env bash
# slm-project-init.sh — Bootstrap a new SLM project with the canonical layout.
#
# Crea la estructura de directorios canónica documentada en
# docs/rules/domain/slm-training-pipeline.md §3 y genera stubs de:
#   - config.yaml (llamando a slm-train-config.sh)
#   - README.md con secciones estándar
#   - .gitignore excluyendo adapters/, gguf/, checkpoints/ (privacy)
#   - datasets/{raw,processed,synthetic}/ (vacíos con .gitkeep)
#   - eval/ con harness.yaml stub
#
# Usage:
#   slm-project-init.sh --name savia-context --model llama-3.2-1b --root projects/
#   slm-project-init.sh --name test --model qwen2.5-0.5b --root /tmp/slm
#
# Exit codes:
#   0 — project bootstrapped
#   1 — project already exists (refuses to overwrite unless --force)
#   2 — usage error
#
# Ref: SPEC-SE-027, docs/rules/domain/slm-training-pipeline.md §3
# Safety: set -uo pipefail, creates files only under --root/--name.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TRAIN_CFG_SCRIPT="$REPO_ROOT/scripts/slm-train-config.sh"

NAME=""
MODEL=""
ROOT=""
FORCE=0

usage() {
  cat <<EOF
Usage:
  $0 --name NAME --model MODEL --root DIR [--force]

  --name NAME   Project slug (kebab-case recommended)
  --model MODEL Base model (llama-3.2-1b, qwen2.5-0.5b, etc)
  --root DIR    Parent directory where project will be created
  --force       Overwrite existing project (destructive)

Creates:
  <root>/<name>/
  ├── config.yaml           (from slm-train-config.sh)
  ├── datasets/{raw,processed,synthetic}/.gitkeep
  ├── adapters/.gitkeep      (gitignored)
  ├── gguf/.gitkeep          (gitignored)
  ├── eval/{harness.yaml stub, results/.gitkeep}
  ├── .gitignore
  └── README.md

Ref: docs/rules/domain/slm-training-pipeline.md §3
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$NAME" ]] && { echo "ERROR: --name required" >&2; exit 2; }
[[ -z "$MODEL" ]] && { echo "ERROR: --model required" >&2; exit 2; }
[[ -z "$ROOT" ]] && { echo "ERROR: --root required" >&2; exit 2; }

# Validate name is slug-like.
if ! [[ "$NAME" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
  echo "ERROR: --name must be slug (lowercase, digits, dots, dashes, underscores)" >&2
  exit 2
fi

# Ensure ROOT exists (but don't create arbitrary paths).
[[ ! -d "$ROOT" ]] && { echo "ERROR: --root directory does not exist: $ROOT" >&2; exit 2; }

PROJECT="$ROOT/$NAME"

# Check existing project.
if [[ -d "$PROJECT" ]]; then
  if [[ "$FORCE" -eq 0 ]]; then
    echo "ERROR: project already exists: $PROJECT (use --force to overwrite)" >&2
    exit 1
  fi
  echo "WARN: --force given, overwriting existing project: $PROJECT"
fi

# Scaffold directory tree.
mkdir -p "$PROJECT/datasets/raw" "$PROJECT/datasets/processed" "$PROJECT/datasets/synthetic"
mkdir -p "$PROJECT/adapters" "$PROJECT/gguf"
mkdir -p "$PROJECT/eval/results"

# .gitkeep placeholders so git tracks empty dirs where appropriate.
touch "$PROJECT/datasets/raw/.gitkeep"
touch "$PROJECT/datasets/processed/.gitkeep"
touch "$PROJECT/datasets/synthetic/.gitkeep"
touch "$PROJECT/eval/results/.gitkeep"

# config.yaml via slm-train-config.sh (if available) or minimal stub.
if [[ -x "$TRAIN_CFG_SCRIPT" ]]; then
  # Use a dataset placeholder path. User will replace after dataset-prep.
  bash "$TRAIN_CFG_SCRIPT" \
    --model "$MODEL" \
    --dataset "datasets/processed/train.jsonl" \
    --output "$PROJECT/config.yaml" >/dev/null 2>&1 || {
      # Fallback minimal stub if train-config rejects the model.
      cat > "$PROJECT/config.yaml" <<YAML
# Minimal SLM config stub (train-config.sh rejected '$MODEL' — edit manually)
model:
  name: "$MODEL"
dataset:
  path: "datasets/processed/train.jsonl"
training:
  num_train_epochs: 3
sovereignty:
  zero_egress: true
YAML
    }
else
  # Minimal stub.
  cat > "$PROJECT/config.yaml" <<YAML
# Minimal SLM config stub
model:
  name: "$MODEL"
dataset:
  path: "datasets/processed/train.jsonl"
training:
  num_train_epochs: 3
sovereignty:
  zero_egress: true
YAML
fi

# eval/harness.yaml stub.
cat > "$PROJECT/eval/harness.yaml" <<YAML
# Eval harness stub — regenerate with:
#   scripts/slm-eval-harness-setup.sh --model <ollama-tag> --seed datasets/processed/eval.jsonl --output-dir eval/
model:
  name: "<fill-after-training>"
  provider: "ollama"
benchmarks:
  - name: "coherence"
    pass_threshold: 4.0
YAML

# .gitignore excluding model weights.
cat > "$PROJECT/.gitignore" <<GITIGNORE
# Model weights (too large + private)
adapters/
gguf/
checkpoints/

# Training artifacts
training.log
*.ckpt
*.safetensors

# Eval runtime outputs
eval/results/*.json
!eval/results/.gitkeep
GITIGNORE

# README.md scaffold.
cat > "$PROJECT/README.md" <<MD
# $NAME

Small Language Model project — $MODEL base.

## Structure

- \`config.yaml\` — Unsloth/TRL training config (SE-027 / SPEC-080)
- \`datasets/raw/\` — source JSONL dumps
- \`datasets/processed/\` — after slm-dataset-prep.sh
- \`datasets/synthetic/\` — after slm-synth-recipe.sh + oumi synth
- \`adapters/\` — LoRA weights (gitignored)
- \`gguf/\` — GGUF exports for Ollama (gitignored)
- \`eval/harness.yaml\` — eval benchmarks config
- \`eval/results/\` — post-train eval JSON

## Pipeline

### 1. Prepare dataset
\`\`\`bash
scripts/slm-dataset-prep.sh --input datasets/raw/chat.jsonl --output datasets/processed/train.jsonl --pii-scrub
\`\`\`

### 2. Synthesize extra data (optional)
\`\`\`bash
scripts/slm-synth-recipe.sh --strategy qa-pairs --input datasets/processed/train.jsonl --output datasets/synthetic/recipe.yaml
# then: oumi synth --config datasets/synthetic/recipe.yaml
\`\`\`

### 3. Train (requires GPU)
\`\`\`bash
# python scripts/slm-train.py --config config.yaml  # deferred until GPU
\`\`\`

### 4. Eval post-training
\`\`\`bash
scripts/slm-eval-harness-setup.sh --model $NAME:latest --seed datasets/processed/eval.jsonl --output-dir eval/
# python scripts/slm-eval-run.py --config eval/eval-config.yaml
\`\`\`

### 5. Validate project layout
\`\`\`bash
scripts/slm-pipeline-validate.sh --project .
\`\`\`

## Sovereignty

- Zero egress by default (\`config.yaml\` sovereignty block)
- Model weights excluded from git (see .gitignore)
- PII scrub is MANDATORY on raw datasets before training

## Generated
\`slm-project-init.sh\` on $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Ref
- \`docs/rules/domain/slm-training-pipeline.md\`
- SPEC-SE-027, SPEC-023, SPEC-080, SE-028, SE-042
MD

echo "slm-project-init: scaffolded $PROJECT"
echo "  model:       $MODEL"
echo "  structure:   datasets/{raw,processed,synthetic} adapters/ gguf/ eval/"
echo "  config:      $PROJECT/config.yaml"
echo "  readme:      $PROJECT/README.md"
echo ""
echo "Next: drop JSONL in datasets/raw/, run slm-dataset-prep.sh."

exit 0
