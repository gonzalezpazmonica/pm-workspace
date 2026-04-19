#!/usr/bin/env bash
# slm-deploy.sh — Orchestrate post-training deployment scaffolding.
#
# Tras training (GPU), corre los 4 pasos scaffolding en secuencia:
#   1. slm-export-gguf.sh  — emite recipe de conversión llama.cpp
#   2. slm-modelfile-gen.sh — emite Modelfile Ollama
#   3. slm-registry.sh register — registra versión en manifest
#   4. [opcional] imprime comandos para ejecutar manualmente
#
# NO ejecuta conversión ni ollama create — solo prepara todos los artifacts
# en el proyecto SLM para que el usuario los corra cuando tenga infra ready.
#
# Usage:
#   slm-deploy.sh --project projects/savia-context --adapter adapters/sft-v1 \
#     --base llama-3.2-1b --version sft-v1 [--quantization q4_k_m] [--persona savia]
#
# Exit codes:
#   0 — todos los artifacts generados
#   1 — scaffolding error (missing dependency scripts)
#   2 — usage error
#
# Ref: SPEC-SE-027 §Deployment orchestration
# Dep: scripts/slm-export-gguf.sh, scripts/slm-modelfile-gen.sh, scripts/slm-registry.sh
# Safety: set -uo pipefail, no red.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

PROJECT=""
ADAPTER=""
BASE=""
VERSION=""
QUANTIZATION="q4_k_m"
PERSONA="default"

usage() {
  cat <<EOF
Usage:
  $0 --project DIR --adapter PATH --base MODEL --version ID [options]

Required:
  --project DIR       SLM project directory (must be slm-pipeline-validate-compliant)
  --adapter PATH      LoRA adapter directory (typically adapters/<version>/)
  --base MODEL        Base model name (llama-3.2-1b, qwen2.5-0.5b, etc)
  --version ID        Version slug for registry + Ollama tag

Optional:
  --quantization Q    GGUF quantization (default q4_k_m)
  --persona NAME      Ollama Modelfile persona (default/savia/code-reviewer/etc)

Genera 3 artifacts en <project>/:
  - gguf/export.sh      (llama.cpp conversion recipe)
  - gguf/Modelfile      (Ollama Modelfile)
  - registry/manifest.json updated (version registered)

NO ejecuta ninguna conversión — scaffolding only.

Ref: SPEC-SE-027 §Deployment orchestration
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --adapter) ADAPTER="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --quantization) QUANTIZATION="$2"; shift 2 ;;
    --persona) PERSONA="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$PROJECT" ]] && { echo "ERROR: --project required" >&2; exit 2; }
[[ -z "$ADAPTER" ]] && { echo "ERROR: --adapter required" >&2; exit 2; }
[[ -z "$BASE" ]] && { echo "ERROR: --base required" >&2; exit 2; }
[[ -z "$VERSION" ]] && { echo "ERROR: --version required" >&2; exit 2; }
[[ ! -d "$PROJECT" ]] && { echo "ERROR: project dir not found: $PROJECT" >&2; exit 2; }

# Check dependency scripts.
for dep in slm-export-gguf.sh slm-modelfile-gen.sh slm-registry.sh; do
  [[ ! -x "$REPO_ROOT/scripts/$dep" ]] && {
    echo "ERROR: required dependency missing: scripts/$dep" >&2
    exit 1
  }
done

PROJECT_NAME=$(basename "$PROJECT")

echo "=== slm-deploy: orchestrating scaffolding for $PROJECT_NAME/$VERSION ==="
echo ""

# Step 1: Export GGUF recipe.
echo "[1/3] Generating GGUF conversion recipe..."
bash "$REPO_ROOT/scripts/slm-export-gguf.sh" \
  --base "$BASE" \
  --adapter "$ADAPTER" \
  --output-dir "$PROJECT/gguf" \
  --quantization "$QUANTIZATION" \
  --name "${PROJECT_NAME}-${VERSION}" 2>&1 | sed 's/^/      /'

GGUF_PATH="$PROJECT/gguf/${PROJECT_NAME}-${VERSION}.${QUANTIZATION}.gguf"

# Step 2: Generate Modelfile.
echo ""
echo "[2/3] Generating Ollama Modelfile..."
bash "$REPO_ROOT/scripts/slm-modelfile-gen.sh" \
  --name "${PROJECT_NAME}:${VERSION}" \
  --gguf "./gguf/${PROJECT_NAME}-${VERSION}.${QUANTIZATION}.gguf" \
  --output "$PROJECT/gguf/Modelfile" \
  --persona "$PERSONA" 2>&1 | sed 's/^/      /'

# Step 3: Register in registry.
echo ""
echo "[3/3] Registering in model registry..."
bash "$REPO_ROOT/scripts/slm-registry.sh" register \
  --project "$PROJECT" \
  --id "$VERSION" \
  --base-model "$BASE" \
  --method sft \
  --ollama-name "${PROJECT_NAME}:${VERSION}" 2>&1 | sed 's/^/      /'

echo ""
echo "=== All 3 artifacts generated ==="
echo ""
echo "Artifacts in $PROJECT/:"
echo "  gguf/export.sh            (llama.cpp conversion recipe)"
echo "  gguf/export-manifest.json (conversion metadata)"
echo "  gguf/Modelfile            (Ollama Modelfile)"
echo "  registry/manifest.json    (version $VERSION registered)"
echo ""
echo "Manual steps to deploy (require GPU/llama.cpp/Ollama installed):"
echo "  1. bash $PROJECT/gguf/export.sh    # merge + quantize → GGUF"
echo "  2. cd $PROJECT/gguf && ollama create ${PROJECT_NAME}:${VERSION} -f Modelfile"
echo "  3. scripts/slm-registry.sh promote --project $PROJECT --id $VERSION"

exit 0
