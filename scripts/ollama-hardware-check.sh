#!/usr/bin/env bash
# ── ollama-hardware-check.sh ─────────────────────────────────────────────────
# Hardware detection + Ollama model recommendation.
# Detects RAM, GPU (nvidia-smi), disk free, and recommends optimal model
# quantization based on available resources.
#
# Usage:
#   bash scripts/ollama-hardware-check.sh
#   bash scripts/ollama-hardware-check.sh --json
#
# Ref: docs/propuestas/SPEC-093-hardware-aware-ollama.md
# Exit: always 0 (informational)
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

JSON_MODE=false
[[ "${1:-}" == "--json" ]] && JSON_MODE=true

# ── GPU bandwidth lookup table (GB/s) ───────────────────────────────────────
# Common NVIDIA GPUs and their memory bandwidth
gpu_bandwidth_lookup() {
  local gpu_name="$1"
  case "$gpu_name" in
    *"4090"*)   echo "1008" ;;
    *"4080"*)   echo "717"  ;;
    *"4070 Ti"*)echo "504"  ;;
    *"4070"*)   echo "504"  ;;
    *"4060 Ti"*)echo "288"  ;;
    *"4060"*)   echo "272"  ;;
    *"3090"*)   echo "936"  ;;
    *"3080"*)   echo "760"  ;;
    *"3070"*)   echo "448"  ;;
    *"3060"*)   echo "360"  ;;
    *"A100"*)   echo "2039" ;;
    *"A6000"*)  echo "768"  ;;
    *"A5000"*)  echo "768"  ;;
    *"A4000"*)  echo "448"  ;;
    *"H100"*)   echo "3350" ;;
    *"T4"*)     echo "320"  ;;
    *"V100"*)   echo "900"  ;;
    *"L40"*)    echo "864"  ;;
    *)          echo "0"    ;;
  esac
}

# ── Detect RAM ──────────────────────────────────────────────────────────────
detect_ram() {
  if command -v free &>/dev/null; then
    free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo "0"
  elif command -v sysctl &>/dev/null; then
    # macOS fallback
    local bytes
    bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
    echo $(( bytes / 1024 / 1024 ))
  else
    echo "0"
  fi
}

# ── Detect GPU ──────────────────────────────────────────────────────────────
detect_gpu() {
  if ! command -v nvidia-smi &>/dev/null; then
    echo "none|0|no GPU detected"
    return
  fi

  local gpu_name vram_mb
  gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "")
  vram_mb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "0")

  if [[ -z "$gpu_name" || "$vram_mb" == "0" ]]; then
    echo "none|0|nvidia-smi found but no GPU detected"
    return
  fi

  echo "${gpu_name}|${vram_mb}|ok"
}

# ── Detect disk free ────────────────────────────────────────────────────────
detect_disk_free() {
  local target="${1:-.}"
  if command -v df &>/dev/null; then
    df -m "$target" 2>/dev/null | awk 'NR==2{print $4}' || echo "0"
  else
    echo "0"
  fi
}

# ── Calculate max model size ────────────────────────────────────────────────
# Returns size in MB
calc_max_model_size() {
  local ram_mb="$1" vram_mb="$2"

  if [[ "$vram_mb" -gt 0 ]]; then
    # GPU path: model <= VRAM * 0.8
    echo $(( vram_mb * 8 / 10 ))
  else
    # CPU-only path: model <= RAM * 0.4
    echo $(( ram_mb * 4 / 10 ))
  fi
}

# ── Recommend quantization ──────────────────────────────────────────────────
# Model sizes (approximate, in MB) for common Ollama models
# qwen2.5:7b  — F16: ~15000, Q8: ~8000, Q4_K_M: ~4500
# qwen2.5:3b  — F16: ~6400,  Q8: ~3400, Q4_K_M: ~2000
# qwen2.5:1.5b— F16: ~3200,  Q8: ~1700, Q4_K_M: ~1000
recommend_quantization() {
  local max_size_mb="$1"

  # F16 of qwen2.5:7b needs ~15000 MB
  if [[ "$max_size_mb" -ge 15000 ]]; then
    echo "F16|qwen2.5:7b|Full precision — best quality"
  # Q8 of qwen2.5:7b needs ~8000 MB
  elif [[ "$max_size_mb" -ge 8000 ]]; then
    echo "Q8|qwen2.5:7b|8-bit quantization — near-lossless"
  # Q4_K_M of qwen2.5:7b needs ~4500 MB
  elif [[ "$max_size_mb" -ge 4500 ]]; then
    echo "Q4_K_M|qwen2.5:7b|4-bit quantization — minimum acceptable"
  # Q8 of qwen2.5:3b needs ~3400 MB
  elif [[ "$max_size_mb" -ge 3400 ]]; then
    echo "Q8|qwen2.5:3b|8-bit quantization — smaller model"
  # Q4_K_M of qwen2.5:3b needs ~2000 MB
  elif [[ "$max_size_mb" -ge 2000 ]]; then
    echo "Q4_K_M|qwen2.5:3b|4-bit quantization — smaller model"
  # Q4_K_M of qwen2.5:1.5b needs ~1000 MB
  elif [[ "$max_size_mb" -ge 1000 ]]; then
    echo "Q4_K_M|qwen2.5:1.5b|4-bit quantization — minimal model"
  else
    echo "NONE|none|Insufficient resources for any model"
  fi
}

# ── Estimate tokens/second ──────────────────────────────────────────────────
# Formula: tps = (bandwidth_GB/s / model_size_GB) * 0.55
estimate_tps() {
  local gpu_name="$1" model_size_mb="$2"

  if [[ "$gpu_name" == "none" || "$model_size_mb" == "0" ]]; then
    echo "0"
    return
  fi

  local bandwidth
  bandwidth=$(gpu_bandwidth_lookup "$gpu_name")

  if [[ "$bandwidth" == "0" ]]; then
    echo "0"
    return
  fi

  # model_size_mb to GB (integer math, multiply first to avoid rounding to 0)
  # tps = (bandwidth / (model_size_mb / 1024)) * 0.55
  # = (bandwidth * 1024 * 55) / (model_size_mb * 100)
  local tps
  tps=$(( (bandwidth * 1024 * 55) / (model_size_mb * 100) ))
  echo "$tps"
}

# ── Model size from quantization recommendation ─────────────────────────────
get_model_size_mb() {
  local quant="$1" model="$2"

  case "${model}|${quant}" in
    "qwen2.5:7b|F16")    echo "15000" ;;
    "qwen2.5:7b|Q8")     echo "8000"  ;;
    "qwen2.5:7b|Q4_K_M") echo "4500"  ;;
    "qwen2.5:3b|Q8")     echo "3400"  ;;
    "qwen2.5:3b|Q4_K_M") echo "2000"  ;;
    "qwen2.5:1.5b|Q4_K_M") echo "1000" ;;
    *)                    echo "0"     ;;
  esac
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
  local ram_mb disk_free_mb gpu_info gpu_name vram_mb gpu_status
  local max_size_mb quant_info quant model description
  local tps model_size_mb

  ram_mb=$(detect_ram)
  disk_free_mb=$(detect_disk_free)

  gpu_info=$(detect_gpu)
  gpu_name=$(echo "$gpu_info" | cut -d'|' -f1)
  vram_mb=$(echo "$gpu_info" | cut -d'|' -f2)
  gpu_status=$(echo "$gpu_info" | cut -d'|' -f3)

  max_size_mb=$(calc_max_model_size "$ram_mb" "$vram_mb")

  quant_info=$(recommend_quantization "$max_size_mb")
  quant=$(echo "$quant_info" | cut -d'|' -f1)
  model=$(echo "$quant_info" | cut -d'|' -f2)
  description=$(echo "$quant_info" | cut -d'|' -f3)

  model_size_mb=$(get_model_size_mb "$quant" "$model")
  tps=$(estimate_tps "$gpu_name" "$model_size_mb")

  if [[ "$JSON_MODE" == "true" ]]; then
    cat <<ENDJSON
{"ram_mb":${ram_mb},"disk_free_mb":${disk_free_mb},"gpu_name":"${gpu_name}","vram_mb":${vram_mb},"max_model_size_mb":${max_size_mb},"recommended_quantization":"${quant}","recommended_model":"${model}","estimated_tps":${tps}}
ENDJSON
    return
  fi

  echo ""
  echo "Ollama Hardware Check"
  echo "====================================="
  echo ""
  echo "[Hardware Detection]"
  printf "  %-25s %s\n" "RAM:" "${ram_mb} MB"
  printf "  %-25s %s\n" "Disk free:" "${disk_free_mb} MB"
  if [[ "$gpu_name" != "none" ]]; then
    printf "  %-25s %s\n" "GPU:" "$gpu_name"
    printf "  %-25s %s\n" "VRAM:" "${vram_mb} MB"
  else
    printf "  %-25s %s\n" "GPU:" "$gpu_status"
  fi
  echo ""
  echo "[Model Recommendation]"
  printf "  %-25s %s\n" "Max model size:" "${max_size_mb} MB"
  printf "  %-25s %s\n" "Recommended model:" "$model"
  printf "  %-25s %s\n" "Quantization:" "$quant — $description"
  if [[ "$tps" -gt 0 ]]; then
    printf "  %-25s %s\n" "Estimated tok/s:" "~${tps} tok/s"
  fi
  echo ""

  if [[ "$quant" == "NONE" ]]; then
    echo "[WARNING] Insufficient resources for Ollama models."
    echo "  Minimum: 1 GB free RAM for qwen2.5:1.5b Q4_K_M"
    echo "  Savia Shield will use regex-only mode (Capa 1)."
  else
    echo "[Install Command]"
    if [[ "$quant" == "F16" ]]; then
      echo "  ollama pull ${model}"
    else
      echo "  ollama pull ${model}"
    fi
  fi
  echo ""
  echo "====================================="
}

main
exit 0
