#!/usr/bin/env bash
set -uo pipefail
# action-shape-classifier.sh — SE-273 S2: Guards de forma de acción
# Evalúa cada acción por 4 propiedades (reversibilidad, radio, perímetro, novedad)
# y decide {proceder | preguntar | bloquear} según matriz declarativa.
# Usage: bash scripts/action-shape-classifier.sh <tool_name> <args...>
# Master switch: SAVIA_ACTION_SHAPE=off

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
RULES="${ROOT}/config/action-shape-rules.yaml"
PROFILE="${ROOT}/output/action-shape-profile.jsonl"
TOOL="${1:-}"; shift 2>/dev/null || true
ACTION_ARGS="$*"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SESSION="${SAVIA_SESSION_ID:-unknown}"

[[ "${SAVIA_ACTION_SHAPE:-on}" == "off" ]] && exit 0
mkdir -p "$(dirname "$PROFILE")"

# ── Score properties (0-2 scale: 0=benign, 1=moderate, 2=risky) ───────

score_reversibility() {
  case "$TOOL" in
    Read|Glob|Grep) echo 0 ;;                    # read-only
    Edit|Write) echo 1 ;;                        # modifies files
    Bash) 
      if echo "$ACTION_ARGS" | grep -qE '(rm |mv |git (push|commit|tag)|chmod|chown)'; then
        echo 2                                    # potentially destructive
      else
        echo 1
      fi
      ;;
    WebFetch|Task) echo 0 ;;                     # no local side effects
    *) echo 1 ;;
  esac
}

score_blast_radius() {
  # Reuse blast-radius.sh if available, otherwise heuristic
  if [[ -x "$ROOT/scripts/blast-radius.sh" && -n "${SAVIA_BLAST_TARGET:-}" ]]; then
    local risk
    risk=$(bash "$ROOT/scripts/blast-radius.sh" --format json "${SAVIA_BLAST_TARGET:-.}" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('risk_score',50))" 2>/dev/null || echo 50)
    if [[ "$risk" -gt 80 ]]; then echo 2
    elif [[ "$risk" -gt 50 ]]; then echo 1
    else echo 0; fi
    return
  fi
  case "$TOOL" in
    Bash) echo 1 ;;    # can affect many files
    Edit) echo 1 ;;    # can affect one file
    Write) echo 2 ;;   # creates/overwrites
    *) echo 0 ;;
  esac
}

score_perimeter_crossing() {
  case "$TOOL" in
    WebFetch) echo 2 ;;                    # network egress
    Bash)
      if echo "$ACTION_ARGS" | grep -qE '(curl|wget|ssh|scp|ftp|nc |telnet)'; then
        echo 2
      elif echo "$ACTION_ARGS" | grep -qE '(git (push|pull|fetch)|gh )'; then
        echo 1
      else echo 0
      fi
      ;;
    Task) echo 1 ;;                        # delegates to subagent
    *) echo 0 ;;
  esac
}

score_novelty() {
  [[ ! -f "$PROFILE" ]] && echo 2 && return   # no history = novel
  local class="${TOOL}"
  local count
  count=$(grep -c "\"class\":\"$class\"" "$PROFILE" 2>/dev/null || echo 0)
  if [[ "$count" -eq 0 ]]; then echo 2         # never used this tool class
  elif [[ "$count" -lt 3 ]]; then echo 1       # rare
  else echo 0                                   # routine
  fi
}

# ── Decision matrix ────────────────────────────────────────────────────
# Hard rule: novelty(2) + irreversibility(2) + perimeter(2) = ask always
decide() {
  local rev="$1" rad="$2" per="$3" nov="$4"
  
  # Critical: novelty + irreversible + perimeter crossing → always ask
  if [[ "$nov" -ge 2 && "$rev" -ge 2 && "$per" -ge 2 ]]; then
    echo "ask"
    return
  fi
  
  # High risk: any two at level 2
  local high_count=0
  [[ "$rev" -ge 2 ]] && high_count=$((high_count + 1))
  [[ "$rad" -ge 2 ]] && high_count=$((high_count + 1))
  [[ "$per" -ge 2 ]] && high_count=$((high_count + 1))
  [[ "$nov" -ge 2 ]] && high_count=$((high_count + 1))
  
  if [[ "$high_count" -ge 2 ]]; then
    echo "ask"
    return
  fi
  
  # Routine operation
  if [[ "$rev" -eq 0 && "$rad" -eq 0 && "$per" -eq 0 && "$nov" -eq 0 ]]; then
    echo "proceed"
    return
  fi
  
  # Default: proceed (permissive for known actions)
  echo "proceed"
}

# ── Main ────────────────────────────────────────────────────────────────
[[ -z "$TOOL" ]] && echo "Usage: $0 <tool_name> [args...]" >&2 && exit 2

rev=$(score_reversibility)
rad=$(score_blast_radius)
per=$(score_perimeter_crossing)
nov=$(score_novelty)
decision=$(decide "$rev" "$rad" "$per" "$nov")

# Record for novelty tracking
echo "{\"ts\":\"$TS\",\"session\":\"$SESSION\",\"class\":\"$TOOL\",\"rev\":$rev,\"rad\":$rad,\"per\":$per,\"nov\":$nov,\"decision\":\"$decision\"}" >> "$PROFILE"

case "$decision" in
  ask)
    echo "ACTION-SHAPE: ask — novelty=$nov rev=$rev perimeter=$per radius=$rad" >&2
    echo "Esta acción combina novedad, irreversibilidad y cruce de perímetro. ¿Proceder?" >&2
    exit 2  # signal: ask human
    ;;
  block)
    echo "ACTION-SHAPE: block — novelty=$nov rev=$rev perimeter=$per radius=$rad" >&2
    exit 1
    ;;
  proceed|*)
    exit 0
    ;;
esac
