#!/usr/bin/env bash
set -euo pipefail
# classify-execution-level.sh — Classify script by origin into execution tier
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

mode="${1:-help}"
target="${2:-}"

usage() {
  cat <<EOF
Usage: classify-execution-level.sh <script-path>
       classify-execution-level.sh --inventory
       classify-execution-level.sh --unclassified

Classifies scripts by ORIGIN into:
  N-anfitrion — workspace code, versioned, reviewed
  N-contenido — Savia-written this turn, third-party, external
  N-hostil    — client code, unverified artifacts
EOF
}

classify_one() {
  local script="$1"
  local level="N-anfitrion"
  local reason="workspace-owned, git-tracked"

  if [[ ! -f "$script" ]]; then
    echo "UNKNOWN: $script (file not found)"
    return
  fi

  # Absolute paths outside workspace
  local abs
  abs=$(readlink -f "$script" 2>/dev/null || realpath "$script" 2>/dev/null || echo "$script")
  if [[ "$abs" != "$ROOT"* && "$abs" == /tmp/* ]]; then
    echo "N-hostil: $script (tmp path)"
    return
  fi
  if [[ "$abs" != "$ROOT"* && "$abs" == /home/* && "$abs" != "$ROOT"* ]]; then
    echo "N-hostil: $script (outside workspace)"
    return
  fi

  # Third-party
  if echo "$script" | grep -qE '(node_modules/|\.nvm/|/snap/|/usr/bin/|/usr/local/)'; then
    echo "N-contenido: $script (third-party)"
    return
  fi

  # Git-tracked check
  cd "$ROOT"
  if git ls-files --error-unmatch "$script" >/dev/null 2>&1; then
    local last_author
    last_author=$(git log -1 --format='%an' -- "$script" 2>/dev/null || echo "unknown")
    if echo "$last_author" | grep -qiE '(claude|savia|bot|agent|github-actions)'; then
      echo "N-contenido: $script (agent-authored)"
    else
      echo "N-anfitrion: $script (human-authored, git-tracked)"
    fi
  else
    echo "N-contenido: $script (not git-tracked)"
  fi
}

case "$mode" in
  help|--help|-h)
    usage; exit 0 ;;
  --inventory)
    cd "$ROOT"
    n_anfitrion=0; n_contenido=0; n_hostil=0
    while IFS= read -r -d '' f; do
      result=$(classify_one "$f")
      case "$result" in
        N-anfitrion:*) n_anfitrion=$((n_anfitrion + 1)) ;;
        N-contenido:*) n_contenido=$((n_contenido + 1)) ;;
        N-hostil:*)    n_hostil=$((n_hostil + 1)) ;;
      esac
      echo "$result"
    done < <(find "$ROOT" -type f \( -name '*.sh' -o -name '*.bash' -o -name '*.py' -o -name '*.js' \) -print0 2>/dev/null)
    total=$((n_anfitrion + n_contenido + n_hostil))
    echo "---"
    echo "N-anfitrion: $n_anfitrion | N-contenido: $n_contenido | N-hostil: $n_hostil | TOTAL: $total"
    ;;
  --unclassified)
    cd "$ROOT"
    local policy_file="$ROOT/containment/container-policy.json"
    local unclassified=0
    while IFS= read -r -d '' f; do
      if [[ -f "$policy_file" ]]; then
        if grep -q "\"$(basename "$f")\"" "$policy_file" 2>/dev/null; then
          continue
        fi
      fi
      local level
      level=$(classify_one "$f" | cut -d: -f1)
      if [[ "$level" == "N-contenido" || "$level" == "N-hostil" ]]; then
        echo "UNCLASSIFIED: $f ($level by heuristic — no explicit declaration)"
        unclassified=$((unclassified + 1))
      fi
    done < <(find "$ROOT" -type f \( -name '*.sh' -o -name '*.bash' \) -print0 2>/dev/null)
    if [[ $unclassified -gt 0 ]]; then
      echo "TOTAL UNCLASSIFIED: $unclassified"
      exit 1
    fi
    echo "All scripts classified."
    ;;
  *)
    classify_one "$mode"
    ;;
esac
