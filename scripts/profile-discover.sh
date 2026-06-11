#!/usr/bin/env bash
set -uo pipefail
# profile-discover.sh — SE-219 S4: auto multi-profile discovery (abtop pattern)
# Ref: docs/propuestas/SE-219-abtop-patterns.md
# Usage: profile-discover.sh list | active | --json
# Exit: 0 always

MODE="list"
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    list)    MODE="list";   shift ;;
    active)  MODE="active"; shift ;;
    --json)  MODE="json";   shift ;;
    --help|-h)
      echo "Usage: profile-discover.sh {list | active | --json}"
      exit 0 ;;
    *) shift ;;
  esac
done

# Resolve active profile:
#   1. $CLAUDE_PROJECT_DIR if set and is a valid profile
#   2. ~/.claude if valid
_active_profile_path() {
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    if [[ -d "${CLAUDE_PROJECT_DIR}/sessions" && -d "${CLAUDE_PROJECT_DIR}/projects" ]]; then
      echo "$CLAUDE_PROJECT_DIR"
      return
    fi
  fi
  local default="${HOME}/.claude"
  if [[ -d "${default}/sessions" && -d "${default}/projects" ]]; then
    echo "$default"
    return
  fi
  echo ""
}

# Collect candidate directories: ~/.claude, ~/.claude-*, and $CLAUDE_EXTRA_PROFILE_DIRS
_collect_candidates() {
  local dirs=()

  # Standard convention
  local d
  for d in "${HOME}/.claude" "${HOME}"/.claude-*; do
    [[ -d "$d" ]] && dirs+=("$d")
  done

  # Extra dirs from env var (colon-separated)
  if [[ -n "${CLAUDE_EXTRA_PROFILE_DIRS:-}" ]]; then
    IFS=':' read -ra extra_dirs <<< "$CLAUDE_EXTRA_PROFILE_DIRS"
    for d in "${extra_dirs[@]}"; do
      [[ -n "$d" && -d "$d" ]] && dirs+=("$d")
    done
  fi

  # Deduplicate while preserving order
  local seen=()
  local item
  for item in "${dirs[@]+"${dirs[@]}"}"; do
    local already=0
    local s
    for s in "${seen[@]+"${seen[@]}"}"; do
      [[ "$s" == "$item" ]] && already=1 && break
    done
    [[ "$already" -eq 0 ]] && seen+=("$item")
  done

  printf '%s\n' "${seen[@]+"${seen[@]}"}"
}

# A directory is a valid profile if it contains both sessions/ and projects/
_is_valid_profile() {
  local d="$1"
  [[ -d "${d}/sessions" && -d "${d}/projects" ]]
}

_run() {
  local active
  active=$(_active_profile_path)

  local profiles=()
  while IFS= read -r candidate; do
    _is_valid_profile "$candidate" && profiles+=("$candidate")
  done < <(_collect_candidates)

  case "$MODE" in
    list)
      if [[ ${#profiles[@]} -eq 0 ]]; then
        exit 0
      fi
      local p
      for p in "${profiles[@]}"; do
        if [[ -n "$active" && "$p" == "$active" ]]; then
          echo "$p (active)"
        else
          echo "$p (inactive)"
        fi
      done
      ;;

    active)
      echo "$active"
      ;;

    json)
      python3 - "${active}" "${profiles[@]+"${profiles[@]}"}" <<'PY'
import sys, json

active = sys.argv[1]
profile_paths = sys.argv[2:] if len(sys.argv) > 2 else []

result = []
for p in profile_paths:
    status = "active" if p == active else "inactive"
    result.append({"path": p, "status": status})

print(json.dumps(result))
PY
      ;;
  esac
}

_run
exit 0
