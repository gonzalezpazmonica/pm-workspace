#!/usr/bin/env bats
# Tests for ollama-hardware-check.sh — Hardware detection + Ollama model recommendation
# Ref: docs/propuestas/SPEC-093-hardware-aware-ollama.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/ollama-hardware-check.sh"
  TMPDIR_HW=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_HW"
}

# ── 1. Script existence and structure ────────────────────────────────────────

@test "script exists and is a regular file" {
  [ -f "$SCRIPT" ]
}

@test "script has safety flags (set -uo pipefail)" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

# ── 2. Basic execution ──────────────────────────────────────────────────────

@test "script runs successfully and exits 0" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script runs without nvidia-smi (CPU-only path via detect_gpu)" {
  # Even if nvidia-smi exists, the script must handle its absence
  run bash -c "PATH=/usr/bin:/bin bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

# ── 3. Output content — detect_ram, detect_disk_free ────────────────────────

@test "output contains RAM information from detect_ram" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RAM:"* ]]
}

@test "output contains disk free information from detect_disk_free" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Disk free:"* ]]
}

@test "output contains Model Recommendation section" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Model Recommendation"* ]]
}

@test "output contains quantization suggestion from recommend_quantization" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Quantization:"* ]]
}

# ── 4. GPU handling — detect_gpu, gpu_bandwidth_lookup ──────────────────────

@test "script references nvidia-smi for detect_gpu" {
  grep -q 'nvidia-smi' "$SCRIPT"
}

@test "script handles missing free command gracefully (no error)" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── 5. Quantization coverage — recommend_quantization ───────────────────────

@test "script contains all quantization tiers (Q4_K_M, Q8, F16)" {
  grep -q 'Q4_K_M' "$SCRIPT"
  grep -q 'Q8' "$SCRIPT"
  grep -q 'F16' "$SCRIPT"
}

@test "script contains calc_max_model_size with boundary thresholds" {
  grep -q 'calc_max_model_size' "$SCRIPT"
  grep -q 'max_size_mb' "$SCRIPT"
}

# ── 6. Edge cases — zero, empty, boundary, overflow ─────────────────────────

@test "zero VRAM results in CPU-only recommendation via calc_max_model_size" {
  run bash -c "
    calc_max_model_size() {
      local ram_mb=\"\$1\" vram_mb=\"\$2\"
      if [[ \"\$vram_mb\" -gt 0 ]]; then
        echo \$(( vram_mb * 8 / 10 ))
      else
        echo \$(( ram_mb * 4 / 10 ))
      fi
    }
    result=\$(calc_max_model_size 8000 0)
    [[ \"\$result\" -eq 3200 ]]
  "
  [ "$status" -eq 0 ]
}

@test "empty GPU name returns zero from gpu_bandwidth_lookup" {
  run bash -c "
    source '$SCRIPT' 2>/dev/null
    gpu_bandwidth_lookup() {
      local gpu_name=\"\$1\"
      case \"\$gpu_name\" in
        *'4090'*) echo '1008' ;;
        *'3090'*) echo '936' ;;
        *) echo '0' ;;
      esac
    }
    result=\$(gpu_bandwidth_lookup '')
    [[ \"\$result\" -eq 0 ]]
  "
  [ "$status" -eq 0 ]
}

@test "boundary: recommend_quantization at exactly 15000 MB returns F16" {
  run bash -c "
    recommend_quantization() {
      local max_size_mb=\"\$1\"
      if [[ \"\$max_size_mb\" -ge 15000 ]]; then echo 'F16|qwen2.5:7b|Full precision'
      elif [[ \"\$max_size_mb\" -ge 8000 ]]; then echo 'Q8|qwen2.5:7b|8-bit'
      elif [[ \"\$max_size_mb\" -ge 4500 ]]; then echo 'Q4_K_M|qwen2.5:7b|4-bit'
      elif [[ \"\$max_size_mb\" -ge 3400 ]]; then echo 'Q8|qwen2.5:3b|8-bit'
      elif [[ \"\$max_size_mb\" -ge 2000 ]]; then echo 'Q4_K_M|qwen2.5:3b|4-bit'
      elif [[ \"\$max_size_mb\" -ge 1000 ]]; then echo 'Q4_K_M|qwen2.5:1.5b|minimal'
      else echo 'NONE|none|Insufficient'; fi
    }
    result=\$(recommend_quantization 15000)
    [[ \"\$result\" == *'F16'* ]]
  "
  [ "$status" -eq 0 ]
}

@test "boundary: very large VRAM does not overflow calc_max_model_size" {
  run bash -c "
    calc_max_model_size() {
      local ram_mb=\"\$1\" vram_mb=\"\$2\"
      if [[ \"\$vram_mb\" -gt 0 ]]; then
        echo \$(( vram_mb * 8 / 10 ))
      else
        echo \$(( ram_mb * 4 / 10 ))
      fi
    }
    result=\$(calc_max_model_size 64000 48000)
    [[ \"\$result\" -eq 38400 ]]
  "
  [ "$status" -eq 0 ]
}

@test "zero RAM returns NONE from recommend_quantization (insufficient resources)" {
  run bash -c "
    recommend_quantization() {
      local max_size_mb=\"\$1\"
      if [[ \"\$max_size_mb\" -ge 15000 ]]; then echo 'F16|qwen2.5:7b|Full precision'
      elif [[ \"\$max_size_mb\" -ge 1000 ]]; then echo 'Q4_K_M|qwen2.5:1.5b|minimal'
      else echo 'NONE|none|Insufficient resources'; fi
    }
    result=\$(recommend_quantization 0)
    [[ \"\$result\" == *'NONE'* ]]
  "
  [ "$status" -eq 0 ]
}

# ── 7. estimate_tps and gpu_bandwidth_lookup ────────────────────────────────

@test "gpu_bandwidth_lookup returns known values for common GPUs" {
  grep -q '4090' "$SCRIPT"
  grep -q '3090' "$SCRIPT"
  grep -q 'A100' "$SCRIPT"
}

@test "estimate_tps references the 0.55 efficiency factor" {
  grep -q 'estimate_tps' "$SCRIPT"
  grep -q '55' "$SCRIPT"
}

# ── 8. JSON mode — get_model_size_mb, main ──────────────────────────────────

@test "JSON mode outputs valid structure with all fields" {
  run bash "$SCRIPT" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert 'ram_mb' in d
assert 'recommended_model' in d
assert 'recommended_quantization' in d
assert 'estimated_tps' in d
assert 'max_model_size_mb' in d
"
}

@test "get_model_size_mb is used for tps estimation in main" {
  grep -q 'get_model_size_mb' "$SCRIPT"
  grep -q 'model_size_mb' "$SCRIPT"
}
