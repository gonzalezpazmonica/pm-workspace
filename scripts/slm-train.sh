#!/usr/bin/env bash
set -uo pipefail
# slm-train.sh — Fine-tune SLMs locally with Unsloth + export to Ollama
# SPEC: SE-027 SLM Training Pipeline
#
# Wraps Unsloth for efficient local fine-tuning with automatic hardware
# detection, model selection, and GGUF export for Ollama deployment.
# Zero data egress — all processing is local.
#
# Usage:
#   bash scripts/slm-train.sh sft    --project X [--base-model auto] [--epochs 2]
#   bash scripts/slm-train.sh dpo    --project X [--base-model PATH]
#   bash scripts/slm-train.sh export --project X [--quantization q4_k_m]
#   bash scripts/slm-train.sh deploy --project X
#   bash scripts/slm-train.sh forget --project X [--confirm]
#   bash scripts/slm-train.sh check

SLM_DATA_DIR="${HOME}/.savia/slm-data"
SLM_REGISTRY="${HOME}/.savia/slm-registry"
SLM_MODELS="${HOME}/.savia/slm-models"

die() { echo "ERROR: $*" >&2; exit 2; }

# ── Hardware Detection ───────────────────────────────────────────────────────

_detect_hardware() {
  # Returns: gpu_name vram_mb ram_mb
  local gpu_name="none" vram_mb=0 ram_mb=0

  ram_mb=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}') || ram_mb=0

  if command -v nvidia-smi >/dev/null 2>&1; then
    gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1) || gpu_name="unknown"
    vram_mb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1) || vram_mb=0
  fi

  echo "$gpu_name" "$vram_mb" "$ram_mb"
}

_select_base_model() {
  local vram_mb="$1"
  # Conservative model selection based on available VRAM for 4-bit QLoRA
  if [[ "$vram_mb" -ge 20000 ]]; then
    echo "unsloth/Llama-3.2-8B-Instruct"
  elif [[ "$vram_mb" -ge 12000 ]]; then
    echo "unsloth/Qwen2.5-7B-Instruct"
  elif [[ "$vram_mb" -ge 8000 ]]; then
    echo "unsloth/SmolLM2-1.7B-Instruct"
  elif [[ "$vram_mb" -ge 6000 ]]; then
    echo "unsloth/SmolLM2-1.7B-Instruct"
  else
    echo ""
  fi
}

# ── Dependency Check ─────────────────────────────────────────────────────────

cmd_check() {
  echo "SLM Training Pipeline — Dependency Check"
  echo ""

  local ok=true

  # Python
  if command -v python3 >/dev/null 2>&1; then
    local pyver; pyver=$(python3 --version 2>&1)
    echo "  Python: $pyver"
  else
    echo "  Python: NOT FOUND"; ok=false
  fi

  # CUDA / GPU
  read -r gpu_name vram_mb ram_mb <<< "$(_detect_hardware)"
  echo "  GPU: $gpu_name (${vram_mb}MB VRAM)"
  echo "  RAM: ${ram_mb}MB"
  [[ "$vram_mb" -lt 6000 ]] && echo "  WARN: <6GB VRAM — training may be very slow or impossible" >&2

  # Unsloth
  if python3 -c "import unsloth" 2>/dev/null; then
    echo "  Unsloth: installed"
  else
    echo "  Unsloth: NOT INSTALLED"
    echo "    Install: pip install unsloth"
    ok=false
  fi

  # TRL
  if python3 -c "import trl" 2>/dev/null; then
    echo "  TRL: installed"
  else
    echo "  TRL: NOT INSTALLED"
    echo "    Install: pip install trl"
    ok=false
  fi

  # Ollama
  if command -v ollama >/dev/null 2>&1; then
    echo "  Ollama: $(ollama --version 2>&1 | head -1)"
  else
    echo "  Ollama: NOT INSTALLED"
    echo "    Install: curl -fsSL https://ollama.ai/install.sh | sh"
    ok=false
  fi

  # Model suggestion
  local model; model=$(_select_base_model "$vram_mb")
  if [[ -n "$model" ]]; then
    echo ""
    echo "  Recommended base model: $model"
  else
    echo ""
    echo "  WARN: Not enough VRAM for any supported model"
    ok=false
  fi

  echo ""
  $ok && echo "  Status: READY" || echo "  Status: MISSING DEPENDENCIES"
}

# ── SFT Training ─────────────────────────────────────────────────────────────

cmd_sft() {
  local project="" base_model="auto" epochs=2 lora_rank=64 batch_size=4
  local learning_rate="5e-5" max_seq_length=2048
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project="$2"; shift 2 ;;
      --base-model) base_model="$2"; shift 2 ;;
      --epochs) epochs="$2"; shift 2 ;;
      --lora-rank) lora_rank="$2"; shift 2 ;;
      --batch-size) batch_size="$2"; shift 2 ;;
      --learning-rate) learning_rate="$2"; shift 2 ;;
      --max-seq-length) max_seq_length="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$project" ]] && die "Usage: sft --project NAME [--base-model MODEL] [--epochs N]"

  local train_file="$SLM_DATA_DIR/$project/train-sft.jsonl"
  [[ -f "$train_file" ]] || die "No training data. Run: slm-data-prep.sh collect + format + split --project $project"

  # Auto-detect hardware and model
  if [[ "$base_model" == "auto" ]]; then
    read -r gpu_name vram_mb ram_mb <<< "$(_detect_hardware)"
    base_model=$(_select_base_model "$vram_mb")
    [[ -z "$base_model" ]] && die "Not enough VRAM ($vram_mb MB). Need at least 6GB."
    echo "Auto-selected model: $base_model (VRAM: ${vram_mb}MB)"
  fi

  local run_id="sft-$(date +%Y%m%d-%H%M%S)"
  local output_dir="$SLM_MODELS/$project/$run_id"
  mkdir -p "$output_dir"

  echo "Starting SFT training..."
  echo "  Project: $project"
  echo "  Base model: $base_model"
  echo "  Epochs: $epochs"
  echo "  LoRA rank: $lora_rank"
  echo "  Output: $output_dir"

  python3 << PYEOF
import json, os, sys
from datetime import datetime

try:
    from unsloth import FastLanguageModel, is_bfloat16_supported
    from trl import SFTTrainer
    from transformers import TrainingArguments
    from datasets import load_dataset
except ImportError as e:
    print(f"ERROR: Missing dependency: {e}", file=sys.stderr)
    print("Install: pip install unsloth trl", file=sys.stderr)
    sys.exit(2)

# Load model with 4-bit quantization
print("Loading model...")
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="$base_model",
    max_seq_length=$max_seq_length,
    load_in_4bit=True,
    dtype=None,  # auto-detect
)

# Apply LoRA
print("Applying LoRA adapter (rank=$lora_rank)...")
model = FastLanguageModel.get_peft_model(
    model,
    r=$lora_rank,
    lora_alpha=$((lora_rank * 2)),
    lora_dropout=0.05,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                     "gate_proj", "up_proj", "down_proj"],
    bias="none",
    use_gradient_checkpointing="unsloth",
    random_state=42,
)

# Load dataset
print("Loading dataset...")
dataset = load_dataset("json", data_files="$train_file", split="train")

# Format for chat
def format_chat(example):
    messages = example.get("messages", [])
    text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=False)
    return {"text": text}

dataset = dataset.map(format_chat)

# Training arguments
args = TrainingArguments(
    per_device_train_batch_size=$batch_size,
    gradient_accumulation_steps=4,
    warmup_steps=50,
    num_train_epochs=$epochs,
    learning_rate=$learning_rate,
    fp16=not is_bfloat16_supported(),
    bf16=is_bfloat16_supported(),
    logging_steps=10,
    save_strategy="epoch",
    output_dir="$output_dir",
    seed=42,
)

# Train
print("Training...")
trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset,
    args=args,
    dataset_text_field="text",
    max_seq_length=$max_seq_length,
)

stats = trainer.train()
final_loss = stats.training_loss

# Save adapter
adapter_dir = os.path.join("$output_dir", "adapter")
model.save_pretrained(adapter_dir)
tokenizer.save_pretrained(adapter_dir)
print(f"Adapter saved to: {adapter_dir}")

# Save training config and results
config = {
    "run_id": "$run_id",
    "project": "$project",
    "base_model": "$base_model",
    "method": "sft",
    "lora_rank": $lora_rank,
    "epochs": $epochs,
    "batch_size": $batch_size,
    "learning_rate": "$learning_rate",
    "max_seq_length": $max_seq_length,
    "final_loss": round(final_loss, 4),
    "train_examples": len(dataset),
    "completed_at": datetime.utcnow().isoformat() + "Z",
}
with open(os.path.join("$output_dir", "config.json"), "w") as f:
    json.dump(config, f, indent=2)

print(f"\nTraining complete!")
print(f"  Final loss: {final_loss:.4f}")
print(f"  Examples: {len(dataset)}")
print(f"  Output: $output_dir")
PYEOF

  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    _register_model "$project" "$run_id" "sft" "$base_model"
    echo ""
    echo "Next steps:"
    echo "  1. Export: bash scripts/slm-train.sh export --project $project"
    echo "  2. Deploy: bash scripts/slm-train.sh deploy --project $project"
  fi
  return $exit_code
}

# ── Export to GGUF ───────────────────────────────────────────────────────────

cmd_export() {
  local project="" quantization="q4_k_m" run_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project="$2"; shift 2 ;;
      --quantization) quantization="$2"; shift 2 ;;
      --run-id) run_id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$project" ]] && die "Usage: export --project NAME [--quantization q4_k_m]"

  # Find latest run if not specified
  if [[ -z "$run_id" ]]; then
    run_id=$(ls -1t "$SLM_MODELS/$project/" 2>/dev/null | head -1) || true
    [[ -z "$run_id" ]] && die "No trained models found for project $project"
  fi

  local model_dir="$SLM_MODELS/$project/$run_id"
  [[ -d "$model_dir/adapter" ]] || die "No adapter found at $model_dir/adapter"

  echo "Exporting to GGUF ($quantization)..."
  echo "  Model: $model_dir"

  # Read base model from config
  local base_model
  base_model=$(python3 -c "import json; print(json.load(open('$model_dir/config.json'))['base_model'])" 2>/dev/null) \
    || die "Cannot read config.json"

  python3 << PYEOF
import sys
try:
    from unsloth import FastLanguageModel
except ImportError:
    print("ERROR: unsloth not installed", file=sys.stderr)
    sys.exit(2)

print("Loading model + adapter for merge...")
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="$model_dir/adapter",
    max_seq_length=2048,
    load_in_4bit=True,
)

# Save merged model as GGUF
gguf_dir = "$model_dir/gguf"
print(f"Exporting GGUF ($quantization) to {gguf_dir}...")

model.save_pretrained_gguf(
    gguf_dir,
    tokenizer,
    quantization_method="$quantization",
)

print(f"GGUF exported to: {gguf_dir}")
PYEOF

  if [[ $? -eq 0 ]]; then
    # Generate Ollama Modelfile
    local gguf_file
    gguf_file=$(find "$model_dir/gguf" -name "*.gguf" -type f | head -1)
    if [[ -n "$gguf_file" ]]; then
      cat > "$model_dir/Modelfile" << MODELFILE
FROM $gguf_file

PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER num_ctx 2048

SYSTEM You are a domain expert for the $project project. Answer based on project documentation, code patterns, and business rules.
MODELFILE
      echo "Modelfile created: $model_dir/Modelfile"
    fi
    echo ""
    echo "Next: bash scripts/slm-train.sh deploy --project $project"
  fi
}

# ── Deploy to Ollama ─────────────────────────────────────────────────────────

cmd_deploy() {
  local project="" run_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project="$2"; shift 2 ;;
      --run-id) run_id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$project" ]] && die "Usage: deploy --project NAME"

  command -v ollama >/dev/null 2>&1 || die "Ollama not installed"

  if [[ -z "$run_id" ]]; then
    run_id=$(ls -1t "$SLM_MODELS/$project/" 2>/dev/null | head -1) || true
    [[ -z "$run_id" ]] && die "No models found for project $project"
  fi

  local model_dir="$SLM_MODELS/$project/$run_id"
  local modelfile="$model_dir/Modelfile"
  [[ -f "$modelfile" ]] || die "No Modelfile. Run 'export' first."

  local ollama_name="savia-${project}:${run_id}"
  echo "Deploying to Ollama as: $ollama_name"

  ollama create "$ollama_name" -f "$modelfile" 2>&1

  if [[ $? -eq 0 ]]; then
    echo ""
    echo "Deployed: $ollama_name"
    echo "Test: ollama run $ollama_name 'Describe the project architecture'"
    echo ""
    echo "To set as default for Savia Dual, add to ~/.savia/dual/config.json:"
    echo "  \"project_models\": { \"$project\": \"$ollama_name\" }"

    # Update registry
    _update_registry_status "$project" "$run_id" "deployed" "$ollama_name"
  fi
}

# ── Forget (RGPD) ───────────────────────────────────────────────────────────

cmd_forget() {
  local project="" confirm=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project="$2"; shift 2 ;;
      --confirm) confirm="yes"; shift ;;
      *) shift ;;
    esac
  done
  [[ -z "$project" ]] && die "Usage: forget --project NAME --confirm"
  [[ "$confirm" != "yes" ]] && die "Add --confirm to delete all SLM data for $project"

  echo "Forgetting SLM data for project: $project"

  # Remove training data
  if [[ -d "$SLM_DATA_DIR/$project" ]]; then
    rm -rf "$SLM_DATA_DIR/$project"
    echo "  Removed training data"
  fi

  # Remove models
  if [[ -d "$SLM_MODELS/$project" ]]; then
    rm -rf "$SLM_MODELS/$project"
    echo "  Removed trained models"
  fi

  # Remove from Ollama
  local ollama_models
  ollama_models=$(ollama list 2>/dev/null | grep "savia-${project}" | awk '{print $1}') || true
  for m in $ollama_models; do
    ollama rm "$m" 2>/dev/null && echo "  Removed Ollama model: $m"
  done

  # Remove registry
  if [[ -d "$SLM_REGISTRY/$project" ]]; then
    rm -rf "$SLM_REGISTRY/$project"
    echo "  Removed registry"
  fi

  echo "Done. All SLM data for '$project' has been deleted."
}

# ── Registry Helpers ─────────────────────────────────────────────────────────

_register_model() {
  local project="$1" run_id="$2" method="$3" base_model="$4"
  local reg_dir="$SLM_REGISTRY/$project"
  mkdir -p "$reg_dir"

  local manifest="$reg_dir/manifest.json"

  python3 -c "
import json, os
from datetime import datetime

manifest_path = '$manifest'
if os.path.exists(manifest_path):
    with open(manifest_path) as f:
        data = json.load(f)
else:
    data = {'project': '$project', 'versions': []}

# Read config if available
config_path = '$SLM_MODELS/$project/$run_id/config.json'
config = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)

entry = {
    'id': '$run_id',
    'base_model': '$base_model',
    'method': '$method',
    'lora_rank': config.get('lora_rank', 64),
    'training_tokens': config.get('train_examples', 0),
    'epochs': config.get('epochs', 0),
    'final_loss': config.get('final_loss', None),
    'created_at': datetime.utcnow().isoformat() + 'Z',
    'status': 'trained'
}
data['versions'].append(entry)

with open(manifest_path, 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
}

_update_registry_status() {
  local project="$1" run_id="$2" status="$3" ollama_name="${4:-}"
  local manifest="$SLM_REGISTRY/$project/manifest.json"
  [[ -f "$manifest" ]] || return

  python3 -c "
import json
with open('$manifest') as f:
    data = json.load(f)
for v in data['versions']:
    if v['id'] == '$run_id':
        v['status'] = '$status'
        if '$ollama_name':
            v['ollama_name'] = '$ollama_name'
with open('$manifest', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
}

# ── Main ─────────────────────────────────────────────────────────────────────

case "${1:-}" in
  sft)     shift; cmd_sft "$@" ;;
  dpo)     shift; die "DPO training: use sft first, then run dpo with --base-model pointing to SFT output" ;;
  export)  shift; cmd_export "$@" ;;
  deploy)  shift; cmd_deploy "$@" ;;
  forget)  shift; cmd_forget "$@" ;;
  check)   shift; cmd_check "$@" ;;
  --help|-h) echo "Usage: slm-train.sh {check|sft|dpo|export|deploy|forget} [options]" ;;
  *) echo "Usage: slm-train.sh {check|sft|dpo|export|deploy|forget} [options]" ;;
esac
