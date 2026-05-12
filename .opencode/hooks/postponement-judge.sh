#!/usr/bin/env bash
set -uo pipefail
# postponement-judge.sh — Stop hook that forces continuation when the assistant
# proposes an unjustified postponement.
#
# Rationale: Savia is a 24/7 agent. No fatigue, no schedule. Phrases like
# "we'll leave it for tomorrow" / "lo dejamos para mañana" are human reflexes
# inherited from training data — they do NOT apply here. If the assistant
# tries to defer work without a valid reason (human approval pending, CI
# running, destructive op awaiting confirmation, user said stop), this hook
# blocks the Stop and forces one more iteration to continue the task.
#
# Wiring: Stop event in .claude/settings.json. Does NOT block irreversible
# operations — only pushes back on procrastination.

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh" && profile_gate "standard"
fi

INPUT=$(cat)

# ── Loop prevention ──────────────────────────────────────────────────────
# 1) stop_hook_active: Claude Code sets this when a previous Stop hook
#    already blocked. Exit immediately to avoid infinite loop.
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [[ "$STOP_ACTIVE" == "true" ]]; then
  exit 0
fi

# 2) Per-session counter with hard cap. Even across hook invocations we never
#    fire more than POSTPONEMENT_JUDGE_MAX times per session (default 2).
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
COUNTER_FILE="/tmp/postponement-judge-${SESSION_ID}.count"
MAX_INTERVENTIONS="${POSTPONEMENT_JUDGE_MAX:-2}"

CURRENT_COUNT=0
[[ -f "$COUNTER_FILE" ]] && CURRENT_COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
if (( CURRENT_COUNT >= MAX_INTERVENTIONS )); then
  exit 0
fi

# ── Transcript extraction ────────────────────────────────────────────────
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[[ -z "$TRANSCRIPT" || ! -f "$TRANSCRIPT" ]] && exit 0

# Last assistant message with TEXT content (skip thinking and tool_use blocks).
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

# Normalize: lowercase + strip Spanish accents to ASCII. UTF-8 byte-safe
# because sed handles each accented char as a single multi-byte token.
# Stripping accents lets us keep patterns ASCII-only (grep [oó] is unsafe
# in POSIX locale because UTF-8 ó is 2 bytes and ends up as a byte class).
NORMALIZED=$(printf '%s' "$LAST_TEXT" \
  | awk '{print tolower($0)}' \
  | sed 's/á/a/g; s/é/e/g; s/í/i/g; s/ó/o/g; s/ú/u/g; s/ñ/n/g; s/ü/u/g')

# ── Postponement patterns (unjustified deferral) ────────────────────────
# Each entry is a single-line ERE. Matched with `grep -E -q`.
POSTPONE_PATTERNS=(
  'lo dejamos (para|aqui|ahi|por hoy)'
  'dejemos(lo)? (para|aqui|ahi|por hoy)'
  'lo retomamos (manana|luego|despues|otro dia|mas tarde)'
  '(seguimos|continuamos|continua|retomamos).{0,30}(manana|luego|despues|otro dia|mas tarde|en otra sesion|en la proxima sesion)'
  'manana (seguimos|continuamos|lo retomamos|vemos|vamos)'
  'en otro momento'
  'mas tarde'
  'para despues'
  'cuando (tengas? tiempo|puedas|vuelvas|tengas un rato)'
  'en (la )?proxima sesion'
  'en otra sesion'
  'por (hoy|ahora) (ya )?esta (bien|ok)'
  'por (hoy|ahora) es suficiente'
  'por (hoy|ahora) lo dejamos'
  '(leave|pick)( this| it)? up (later|tomorrow)'
  "we'?ll (continue|pick (this|it) up|resume) (later|tomorrow|another time)"
  'we will (continue|pick (this|it) up|resume) (later|tomorrow|another time)'
  "let'?s (continue|pick (this|it) up|resume) (later|tomorrow|another time)"
  '(see|talk) you tomorrow'
  'come back (later|tomorrow)'
  'for (now|today),? (that|this) is (enough|it)'
)

POSTPONE_HIT=""
for pat in "${POSTPONE_PATTERNS[@]}"; do
  if printf '%s' "$NORMALIZED" | grep -qE "$pat"; then
    POSTPONE_HIT="$pat"
    break
  fi
done

[[ -z "$POSTPONE_HIT" ]] && exit 0

# ── Justification patterns (reasons that legitimize the stop) ───────────
JUSTIFY_PATTERNS=(
  'esperando (aprobacion|revision|merge|ci|aprobar|que el usuario|confirmacion)'
  'pendiente de (aprobacion|revision|merge|ci|confirmacion|revisar)'
  'requiere (aprobacion|revision|confirmacion) humana'
  'code review e1'
  'e1 humano'
  'revision humana'
  'approval humano'
  'bloqueado por'
  'blocked (by|on)'
  'waiting (for|on) (approval|review|human|ci|merge|user|confirmation)'
  'pending (approval|review|human|merge)'
  'human (approval|review|confirmation) (required|needed|pending)'
  'usuario pidio (parar|pausar|detener)'
  'user (requested|asked) (to )?(stop|pause|halt)'
  'rate limit'
  'quota exceeded'
  'api down'
  'network (unavailable|down)'
  'external (dependency|service) (unavailable|down)'
  'no hay (mas )?tareas'
  'nothing (left )?to do'
  'tareas? completa(da)?s?'
  'task(s)? complete'
  'pr (creado|abierto|mergeado) y esperando'
)

for pat in "${JUSTIFY_PATTERNS[@]}"; do
  if printf '%s' "$NORMALIZED" | grep -qE "$pat"; then
    # Legitimate reason → allow stop
    exit 0
  fi
done

# ── Block the Stop and force continuation ───────────────────────────────
echo $((CURRENT_COUNT + 1)) > "$COUNTER_FILE"

REASON="Postponement Judge: detected unjustified deferral in your response. Savia is a 24/7 agent — no fatigue, no schedule. Phrases like 'we'll continue tomorrow', 'lo dejamos para mañana', 'in another session' are human reflexes that do not apply. No pending human approval, CI wait, destructive-op confirmation, or explicit user stop was stated in your message. Continue the task NOW: identify the next concrete step and execute it. If there genuinely is a blocker, state it explicitly (waiting for X, pending human approval of Y, blocked on Z) and then the Stop will be allowed."

jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
exit 0
