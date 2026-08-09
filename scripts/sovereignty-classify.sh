#!/usr/bin/env bash
# sovereignty-classify.sh — SE-314: clasificador determinista de soberanía de datos.
#
# Reemplaza a ollama-classify.sh como API pública (que queda como shim deprecado).
# Diseño (SE-314 §4):
#   - Capa 1 determinista: regex de credenciales/IPs/base64 → BLOCK sin LLM
#   - Capa 2: LLM local (Ollama) SOLO para contexto de negocio/personas, con
#     seed fijo + top_k=1 + format=json + num_predict=32 (determinismo)
#   - Salida JSON estricta (schema savia.classify/2.0) con confidence + hash
#   - Caché por hash de contenido (output/classifier-cache/{sha256}.json)
#
# Uso:
#   echo 'text' | sovereignty-classify.sh [--context-path <path>] [--model <id>] [--no-cache]
#
# Salida (JSON):
#   {schema, hash, label, confidence, deterministic_matches[],
#    llm_verdict, llm_confidence, cache_hit, model, seed, prompt_version}
#
# Exit codes: 0 ok, 1 Ollama indisponible (UNAVAILABLE), 2 usage.
set -uo pipefail

CONTEXT_PATH=""
MODEL="${OLLAMA_CLASSIFY_MODEL:-qwen2.5:3b}"
NO_CACHE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --context-path) CONTEXT_PATH="$2"; shift 2 ;;
    --model)        MODEL="$2"; shift 2 ;;
    --no-cache)     NO_CACHE=1; shift ;;
    *) echo "usage: sovereignty-classify.sh [--context-path <p>] [--model <id>] [--no-cache]" >&2; exit 2 ;;
  esac
done

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PROMPT_FILE="$REPO_ROOT/config/classifier/prompt-v2.txt"
CACHE_DIR="$REPO_ROOT/output/classifier-cache"
PROMPT_VERSION="classify-prompt-v2"
SEED=42
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
OLLAMA_TIMEOUT="${OLLAMA_TIMEOUT:-15}"

# Leer texto de stdin (o argumento)
TEXT=""
if [[ ! -t 0 ]]; then
  TEXT=$(cat 2>/dev/null)
fi
[[ -z "$TEXT" ]] && TEXT="${1:-}"
[[ -z "$TEXT" ]] && { echo "ERROR: No text provided. Usage: echo 'text' | $0" >&2; exit 1; }
TEXT="${TEXT:0:20000}"

# ── Hash de contenido (normalizado) ─────────────────────────────────────────
NORM_TEXT="$(printf '%s' "$TEXT" | python3 -c "import sys,unicodedata;print(unicodedata.normalize('NFKC',sys.stdin.read()))" 2>/dev/null || printf '%s' "$TEXT")"
CONTENT_HASH="$(printf '%s' "$NORM_TEXT" | sha256sum | cut -d' ' -f1)"

# ── Capa 1: detección determinista (siempre bloquea en N1, sin LLM) ─────────
DETECTED=()
DET_COUNT=0
detect() {
  local kind="$1"; shift
  local pat="$1"
  # Soporte para '--' como separador (patrones que empiezan por guion)
  [[ "$pat" == "--" ]] && pat="$2"
  if printf '%s' "$NORM_TEXT" | grep -qiE -- "$pat" 2>/dev/null; then
    DETECTED+=("$kind")
    DET_COUNT=$((DET_COUNT + 1))
  fi
}
detect "aws_key"          "AKIA[0-9A-Z]{16}"
detect "github_token"     "(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82,})"
detect "openai_key"       'sk-(proj-)?[A-Za-z0-9]{32,}'
detect "connection_string" '(jdbc:|mongodb[+]srv://|Server=.*[Pp]assword=)'
detect "azure_sas"        'sv=20[0-9]{2}-'
detect "private_key"      -- '-----BEGIN.*PRIV[AEIOU]*TE KEY-----'
detect "internal_ip"      '(192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+)'
detect "dni_nif"            '(^|[^0-9])[0-9]{8}[A-Za-z]([^0-9]|$)'

DET_JSON="[]"
if [[ "$DET_COUNT" -gt 0 ]]; then
  DET_JSON="[\"$(printf '%s' "${DETECTED[@]}" | paste -sd, - | sed 's/,/","/g')\"]"
fi

# ── Caché (SE-314 S4) ──────────────────────────────────────────────────────
CACHE_HIT=false
CACHE_FILE=""
if [[ "$NO_CACHE" -eq 0 ]]; then
  mkdir -p "$CACHE_DIR" 2>/dev/null || true
  CACHE_FILE="$CACHE_DIR/${CONTENT_HASH}.json"
  if [[ -f "$CACHE_FILE" ]]; then
    # Invalida si cambia modelo o prompt_version
    C_MODEL="$(jq -r '.model // empty' "$CACHE_FILE" 2>/dev/null)"
    C_PROMPT="$(jq -r '.prompt_version // empty' "$CACHE_FILE" 2>/dev/null)"
    if [[ "$C_MODEL" == "$MODEL" && "$C_PROMPT" == "$PROMPT_VERSION" ]]; then
      jq -c '. + {cache_hit:true}' "$CACHE_FILE" 2>/dev/null
      exit 0
    fi
  fi
fi

# ── Capa 1 concluyente: secreto real → BLOCK sin LLM ────────────────────────
if [[ "$DET_COUNT" -gt 0 ]]; then
  echo "{\"schema\":\"savia.classify/2.0\",\"hash\":\"sha256:${CONTENT_HASH}\",\"label\":\"confidential\",\"confidence\":0.99,\"deterministic_matches\":${DET_JSON},\"llm_verdict\":\"\",\"llm_confidence\":0,\"cache_hit\":${CACHE_HIT},\"model\":\"${MODEL}\",\"seed\":${SEED},\"prompt_version\":\"${PROMPT_VERSION}\"}"
  exit 0
fi

# ── Capa 2: LLM local (solo contexto, sin match determinista) ──────────────
# Contenido muy corto o sin contexto de negocio → public sin LLM
if [[ ${#TEXT} -lt 50 ]]; then
  echo "{\"schema\":\"savia.classify/2.0\",\"hash\":\"sha256:${CONTENT_HASH}\",\"label\":\"public\",\"confidence\":0.65,\"deterministic_matches\":${DET_JSON},\"llm_verdict\":\"public\",\"llm_confidence\":0.65,\"cache_hit\":${CACHE_HIT},\"model\":\"${MODEL}\",\"seed\":${SEED},\"prompt_version\":\"${PROMPT_VERSION}\"}"
  exit 0
fi

# Verificar Ollama
if ! curl -s --max-time 5 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
  echo "{\"schema\":\"savia.classify/2.0\",\"hash\":\"sha256:${CONTENT_HASH}\",\"label\":\"ambiguous\",\"confidence\":0.5,\"deterministic_matches\":${DET_JSON},\"llm_verdict\":\"unavailable\",\"llm_confidence\":0,\"cache_hit\":${CACHE_HIT},\"model\":\"${MODEL}\",\"seed\":${SEED},\"prompt_version\":\"${PROMPT_VERSION}\",\"error\":\"ollama_unavailable\"}"
  exit 1
fi

export SAVIA_CLASSIFY_PROMPT_FILE="$PROMPT_FILE"
export OLLAMA_CLASSIFY_MODEL="$MODEL"
PAYLOAD=$(printf '%s' "$NORM_TEXT" | python3 -c "
import sys, json, os
text = sys.stdin.read()[:20000]
try:
    with open(os.environ.get('SAVIA_CLASSIFY_PROMPT_FILE','')) as f:
        prompt = f.read()
except Exception:
    prompt = 'Classify. JSON {label, confidence}.'
prompt_full = prompt + '\n' + text + '\n[END DATA]'
payload = {'model': os.environ.get('OLLAMA_CLASSIFY_MODEL','qwen2.5:3b'),
           'prompt': prompt_full, 'stream': False, 'format': 'json',
           'options': {'temperature': 0, 'seed': 42, 'top_k': 1, 'num_predict': 32}}
print(json.dumps(payload))
" 2>/dev/null)

RESPONSE=$(curl -s --max-time "$OLLAMA_TIMEOUT" "$OLLAMA_URL/api/generate" -d "$PAYLOAD" 2>/dev/null)
if [[ $? -ne 0 ]] || [[ -z "$RESPONSE" ]]; then
  echo "{\"schema\":\"savia.classify/2.0\",\"hash\":\"sha256:${CONTENT_HASH}\",\"label\":\"ambiguous\",\"confidence\":0.5,\"deterministic_matches\":${DET_JSON},\"llm_verdict\":\"unavailable\",\"llm_confidence\":0,\"cache_hit\":${CACHE_HIT},\"model\":\"${MODEL}\",\"seed\":${SEED},\"prompt_version\":\"${PROMPT_VERSION}\"}"
  exit 1
fi

# ── Parsear salida LLM (JSON estricto con fallback) ─────────────────────────
LLM_OUT=$(printf '%s' "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    resp = data.get('response', '')
    try:
        obj = json.loads(resp)
    except Exception:
        obj = {}
    label = str(obj.get('label', 'ambiguous')).lower()
    confidence = float(obj.get('confidence', 0.5))
    if label not in ('public','confidential','ambiguous'):
        label = 'ambiguous'
    print(json.dumps({'label': label, 'confidence': confidence}))
except Exception:
    print(json.dumps({'label': 'ambiguous', 'confidence': 0.5}))
" 2>/dev/null)

LLM_LABEL=$(printf '%s' "$LLM_OUT" | jq -r '.label // "ambiguous"' 2>/dev/null)
LLM_CONF=$(printf '%s' "$LLM_OUT" | jq -r '.confidence // 0.5' 2>/dev/null)

# ── Decisión final por umbral (SE-314 S2) ───────────────────────────────────
LABEL="public"; CONF=0.5
ge() { python3 -c "import sys; sys.exit(0 if float('$1') >= float('$2') else 1)" 2>/dev/null; }
if [[ "$LLM_LABEL" == "confidential" ]]; then
  if ge "$LLM_CONF" 0.70; then
    LABEL="confidential"; CONF="$LLM_CONF"
  else
    LABEL="public"; CONF="$LLM_CONF"
  fi
elif [[ "$LLM_LABEL" == "ambiguous" ]]; then
  LABEL="ambiguous"; CONF="$LLM_CONF"
fi

RESULT="{\"schema\":\"savia.classify/2.0\",\"hash\":\"sha256:${CONTENT_HASH}\",\"label\":\"${LABEL}\",\"confidence\":${CONF},\"deterministic_matches\":${DET_JSON},\"llm_verdict\":\"${LLM_LABEL}\",\"llm_confidence\":${LLM_CONF},\"cache_hit\":${CACHE_HIT},\"model\":\"${MODEL}\",\"seed\":${SEED},\"prompt_version\":\"${PROMPT_VERSION}\"}"

# ── Guardar caché ───────────────────────────────────────────────────────────
if [[ "$NO_CACHE" -eq 0 && -n "$CACHE_FILE" ]]; then
  printf '%s\n' "$RESULT" > "$CACHE_FILE" 2>/dev/null || true
fi

echo "$RESULT"
exit 0
