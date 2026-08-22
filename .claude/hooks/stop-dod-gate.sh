#!/usr/bin/env bash
set -uo pipefail
# stop-dod-gate.sh — SE-336 S2: DoD gate determinista sobre la respuesta final.
#
# Lee el último mensaje de texto del assistant (mismo parser que
# postponement-judge.sh) y aplica reglas DOD deterministas:
#
#   DOD-001  Promesa de mejora sin acción de respaldo en el turno  → BLOCK*
#            ("la próxima vez X", "a partir de ahora X", ...) sin diff/artefacto
#   DOD-002  Afirmación material sin referencia verificable        → WARN
#   DOD-003  Idioma de la respuesta ≠ idioma del perfil activo     → WARN
#
# *BLOCK solo en modo block (SAVIA_DOD_GATE_MODE=block). Por defecto warn
#  (SE-336 S2: primer sprint WARN-only, promoción condicionada a FP medidos).
#
# Antiloop (RN-02): máximo 1 bloqueo por sesión — stop_hook_active o contador
# hace pasar la segunda invocación. Fail-open operativo: exit 0 siempre.
#
# Wiring: Stop event en .claude/settings.json. PURE_BASH, sin red, sin LLM.
# Master switch: SAVIA_DOD_GATE=off → exit 0 inmediato.

MASTER_SWITCH="${SAVIA_DOD_GATE:-on}"
GATE_MODE="${SAVIA_DOD_GATE_MODE:-warn}"
LOG_DIR="${SAVIA_DOD_GATE_LOG_DIR:-${SAVIA_WORKSPACE_DIR:-$(pwd)}/output/turn-sdlc}"

[[ "$MASTER_SWITCH" == "off" ]] && exit 0

INPUT=$(cat)

# ── Antiloop 1: stop_hook_active (Claude Code marca re-entrada) ─────────────
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
[[ "$STOP_ACTIVE" == "true" ]] && exit 0

# ── Antiloop 2: contador por sesión, hard cap 1 bloqueo ─────────────────────
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
COUNTER_FILE="${TMPDIR:-/tmp}/stop-dod-gate-${SESSION_ID}.count"
[[ -f "$COUNTER_FILE" ]] && exit 0

# ── Transcript: último mensaje de texto del assistant ───────────────────────
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[[ -z "$TRANSCRIPT" || ! -f "$TRANSCRIPT" ]] && exit 0

LAST_TEXT=$(tac "$TRANSCRIPT" 2>/dev/null | head -50 | while IFS= read -r line; do
  role=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
  [[ "$role" != "assistant" ]] && continue
  text=$(echo "$line" | jq -r '.message.content[]? | select(.type=="text") | .text' 2>/dev/null)
  if [[ -n "$text" ]]; then
    printf '%s\n' "$text"
    break
  fi
done)
[[ -z "$LAST_TEXT" ]] && exit 0

# ── Normalización: lowercase + acentos a ASCII (patrón postponement-judge) ──
NORMALIZED=$(printf '%s' "$LAST_TEXT" \
  | awk '{print tolower($0)}' \
  | sed 's/á/a/g; s/é/e/g; s/í/i/g; s/ó/o/g; s/ú/u/g; s/ñ/n/g; s/ü/u/g')

mkdir -p "$LOG_DIR" 2>/dev/null || LOG_DIR="${TMPDIR:-/tmp}"
log_event() {
  # Privacidad: hash del texto, nunca el texto completo.
  local rule="$1" severity="$2" detail="$3"
  local qh
  qh=$(printf '%s' "$LAST_TEXT" | sha256sum | cut -c1-16)
  printf '{"ts":"%s","rule":"%s","severity":"%s","detail":"%s","query_hash":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rule" "$severity" "$detail" "$qh" \
    >> "$LOG_DIR/dod-gate.jsonl" 2>/dev/null || true
}

# ── DOD-001: promesa de mejora sin acción ────────────────────────────────────
PROMISE_PATTERNS=(
  'la proxima vez'
  'a partir de ahora'
  'de ahora en adelante'
  'en adelante (lo|hare|usare|seguire)'
  'en el futuro (lo|hare|usare|seguire|aplicare)'
  'nunca mas voy? a'
  'no volvere? a'
  'next time i( |\x27)?(will|will not|won|\x27ll)'
  'from now on i( |\x27)?(will|\x27ll)'
  'going forward,? i( |\x27)?(will|\x27ll)'
)
PROMISE_HIT=""
for pat in "${PROMISE_PATTERNS[@]}"; do
  if printf '%s' "$NORMALIZED" | grep -qE "$pat"; then
    PROMISE_HIT="$pat"
    break
  fi
done

if [[ -n "$PROMISE_HIT" ]]; then
  # ¿Hay acción de respaldo ese turno? Detección delimitada al CWD del hook:
  # diff del working tree o ficheros recientes (≤30 min) fuera de dirs de ruido.
  ACTION_TAKEN=false
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
      ACTION_TAKEN=true
    fi
  fi
  if [[ "$ACTION_TAKEN" != "true" ]]; then
    if find . -maxdepth 4 -newermt '-30 minutes' -type f \
         -not -path './.git/*' -not -path './output/*' -not -path './node_modules/*' \
         -not -path './.scm/*' -not -path './vaults/*' -not -name '*.count' \
         -print -quit 2>/dev/null | grep -q .; then
      ACTION_TAKEN=true
    fi
  fi

  if [[ "$ACTION_TAKEN" != "true" ]]; then
    log_event "DOD-001" "block" "promise-pattern without backing action"
    if [[ "$GATE_MODE" == "block" ]]; then
      echo 1 > "$COUNTER_FILE" 2>/dev/null || true
      REASON="DoD Gate [DOD-001]: tu respuesta contiene una promesa de mejora sin acción de respaldo en este turno (patrón: '$PROMISE_HIT'). Una promesa sin acción es una afirmación vacía (LP-20260822-b20596e1). Continúa UNA iteración: convierte la promesa en acción concreta (crea el artefacto, edita el fichero, registra la propuesta) o reformula la respuesta sin la promesa. No repitas la promesa."
      jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
    fi
    exit 0
  fi
fi

# ── DOD-002: afirmación de resultado con cifras sin referencia verificable ───
# Solo WARN (RN-03). Heurística conservadora: cifras de resultado + ausencia
# de file:line, rutas de test/scripts/docs o comando bash en el propio texto.
if printf '%s' "$NORMALIZED" | grep -qE '[0-9]+ */ *[0-9]+ *(tests?|verde|green|pass)|[0-9]+ (de|/) [0-9]+ (passing|pasando|pasan)'; then
  if ! printf '%s' "$LAST_TEXT" | grep -qE ':[0-9]+|tests/[a-zA-Z0-9._-]+|scripts/[a-zA-Z0-9._-]+|docs/[a-zA-Z0-9._/-]+|\.bats|\.sh|bash |output/[a-zA-Z0-9._/-]+'; then
    log_event "DOD-002" "warn" "result-claim without verifiable reference"
    echo '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"DoD Gate [DOD-002]: has afirmado resultados con cifras sin referencia verificable (file:line, ruta de test, comando). Cita la fuente de cada cifra antes de entregar."}}'
    exit 0
  fi
fi

# ── DOD-003: idioma de la respuesta ≠ idioma del perfil ──────────────────────
WS_ROOT="${SAVIA_WORKSPACE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROFILE_LANG="es"
ACTIVE_USER="$WS_ROOT/.claude/profiles/active-user.md"
if [[ -f "$ACTIVE_USER" ]]; then
  SLUG=$(awk '/^active_slug:/{gsub(/[",]/,""); sub(/^[^:]*:[[:space:]]*/,""); print; exit}' "$ACTIVE_USER" 2>/dev/null)
  PREF="$WS_ROOT/.claude/profiles/users/$SLUG/preferences.md"
  [[ -f "$PREF" ]] && \
    PROFILE_LANG=$(awk '/^language:/{gsub(/[",]/,""); sub(/^[^:]*:[[:space:]]*/,""); print; exit}' "$PREF" 2>/dev/null)
fi
PROFILE_LANG="${PROFILE_LANG:-es}"

# Heurística de detección de idioma (stopwords):
detect_lang() {
  local t="$1"
  local es en
  es=$(printf '%s' "$t" | grep -oiE '\b(que|de|la|el|los|las|una|para|con|pero|porque|este|esta|como|muy|mas|sin|sobre|tambien|ya|hoy|hemos|estoy|estamos|he|has)\b' 2>/dev/null | wc -l)
  en=$(printf '%s' "$t" | grep -oiE '\b(the|and|of|to|in|is|it|that|for|with|this|but|not|are|was|we|you|i)\b' 2>/dev/null | wc -l)
  if (( en > es * 2 && en > 3 )); then printf 'en'; else printf 'es'; fi
}
if [[ "$PROFILE_LANG" == "es" ]]; then
  DETECTED=$(detect_lang "$LAST_TEXT")
  if [[ "$DETECTED" == "en" ]]; then
    log_event "DOD-003" "warn" "response language (en) != profile language (es)"
    echo '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"DoD Gate [DOD-003]: la respuesta detectada está en inglés pero el idioma del perfil activo es español. Responde en el idioma del perfil."}}'
    exit 0
  fi
fi

exit 0
