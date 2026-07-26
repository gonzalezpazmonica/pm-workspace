#!/usr/bin/env bash
set -uo pipefail
# unlimited-auth-detector.sh — SE-273 S4: Detecta delegación sin límite
#
# Evalúa UserPromptSubmit en busca de patrones de autorización ilimitada.
# Si detecta, responde pidiendo el límite en vez de ejecutar u obedecer.
#
# Patrones detectados (ES + EN):
#   "lo que sea necesario", "a toda costa", "sin preguntarme",
#   "no importa como", "salta lo que haga falta",
#   "whatever it takes", "at all costs", "dont ask me",
#   "no matter what", "do everything needed"
#
# Registra en ledger de relación para SE-255 S3.
# Master switch: SAVIA_UNLIMITED_AUTH_DETECTOR=off

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LEDGER="${ROOT}/output/relation-ledger.jsonl"
DETECTOR_LOG="${ROOT}/output/unlimited-auth-detections.jsonl"
INPUT="${1:-}"

[[ "${SAVIA_UNLIMITED_AUTH_DETECTOR:-on}" == "off" ]] && exit 0
mkdir -p "$(dirname "$DETECTOR_LOG")"

# ── Detection patterns ──────────────────────────────────────────────────
PATTERNS=(
  "lo que sea necesario"
  "lo que haga falta"
  "a toda costa"
  "sin preguntarme"
  "sin preguntar"
  "no importa como"
  "no me preguntes"
  "salta lo que haga falta"
  "haz lo que tengas que hacer"
  "como sea"
  "cueste lo que cueste"
  "sea como sea"
  "whatever it takes"
  "at all costs"
  "don'?t ask me"
  "no matter what"
  "do (everything|whatever|anything) (it takes|needed|necessary)"
  "by any means"
  "just get it done"
  "i don'?t care how"
  "figure it out"
  "don'?t bother me"
  "haz todo"
  "sin limites"
  "sin restricciones"
)

# ── Default limits response ─────────────────────────────────────────────
DEFAULT_LIMITS=$(cat << 'LIMITS'
Límites por defecto aplicados a esta tarea:
1. No modificar ficheros fuera del workspace declarado
2. No ejecutar comandos destructivos sin confirmación (rm, chmod 777, curl|sh)
3. No acceder a dominios fuera de la allowlist de egreso (SE-273 S3)
4. Presupuesto máximo: el declarado para el tipo de tarea
5. No auto-aprobar PRs ni hacer merge autónomo
6. No delegar en subagentes sin límite de profundidad (max 2 niveles)
Si necesitas ampliar estos límites, especifica qué y por qué.
LIMITS
)

# ── Detection ───────────────────────────────────────────────────────────
detect_unlimited() {
  local text="$1"
  local detected=""
  
  for pattern in "${PATTERNS[@]}"; do
    if echo "$text" | grep -qiP "$pattern" 2>/dev/null; then
      detected="$detected|$pattern"
    fi
  done
  
  echo "${detected#|}"
}

# ── Main ────────────────────────────────────────────────────────────────
if [[ -z "$INPUT" ]]; then
  # Read from stdin
  INPUT=$(cat)
fi

# Skip empty input
[[ -z "$INPUT" ]] && exit 0

# Skip if input is from an agent (not human)
if echo "$INPUT" | grep -q '"role":"agent"' 2>/dev/null; then
  exit 0
fi

# Extract user text
USER_TEXT="$INPUT"
if echo "$INPUT" | grep -q '"text"' 2>/dev/null; then
  USER_TEXT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('text',''))" 2>/dev/null || echo "$INPUT")
fi

DETECTED=$(detect_unlimited "$USER_TEXT")

if [[ -n "$DETECTED" ]]; then
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  # Log detection
  cat >> "$DETECTOR_LOG" <<JSON
{"ts":"$TS","patterns":"$DETECTED","text_preview":"${USER_TEXT:0:200}"}
JSON
  
  # Log to relation ledger (SE-255 S3)
  if [[ -d "$(dirname "$LEDGER")" ]]; then
    cat >> "$LEDGER" <<JSON
{"ts":"$TS","event":"unlimited_auth_detected","patterns":"$DETECTED","recurrence_check":true}
JSON
  fi
  
  # Emit the bounded-response prompt to stderr for hook chaining
  cat >&2 <<RESPONSE
════════════════════════════════════════════════
DETECTED: autorización sin límite explícito

Patrones detectados: $DETECTED

La tarea requiere un límite declarado antes de proceder.
Por favor especifica:
  - ¿Qué NO debe hacerse?
  - ¿Qué presupuesto máximo (tiempo, tokens, coste)?
  - ¿Qué resultado es inaceptable?

$DEFAULT_LIMITS
════════════════════════════════════════════════
RESPONSE

  # Check recurrence (3+ in window → suggest CRITERIO amendment)
  recurrence=$(grep -c "unlimited_auth_detected" "$DETECTOR_LOG" 2>/dev/null || echo 0)
  if [[ "$recurrence" -ge 3 ]]; then
    echo "RECURRENCE: $recurrence unlimited-auth detections. Consider adding a CRITERIO.md entry for this domain." >&2
  fi

  exit 0
fi

exit 0
