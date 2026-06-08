#!/bin/bash
# block-pat-file-write.sh — SPEC-SE-036 Slice 2: block writes to PAT file paths
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md
set -uo pipefail

CHECK_ONLY=0
INPUT_PATH=""

# ── PAT path patterns ──────────────────────────────────────────────────────────
# Matches paths that look like PAT/token storage files

_is_pat_path() {
  local path="$1"
  # Normalise to lowercase for pattern matching
  local lower
  lower="$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')"

  case "$lower" in
    # Glob-style matches (case insensitive via lowercase)
    */.pat_file)           return 0 ;;
    *pat*.token)           return 0 ;;
    *pat_file*)            return 0 ;;
    *_pat)                 return 0 ;;
    *_pat.*)               return 0 ;;
    # Exact known filenames
    *devops-pat)           return 0 ;;
    *github-pat)           return 0 ;;
    *azure-pat)            return 0 ;;
    *anthropic_api_key*)   return 0 ;;
    *anthropic_api_key_file*) return 0 ;;
    # Generic patterns for common PAT file names
    */pat)                 return 0 ;;
    */pat.*)               return 0 ;;
    *.pat)                 return 0 ;;
  esac

  # Case-insensitive match for ANTHROPIC_API_KEY_FILE (any case variant)
  case "$path" in
    *ANTHROPIC_API_KEY*)   return 0 ;;
    *ANTHROPIC_API_KEY_FILE*) return 0 ;;
  esac

  return 1
}

# ── argument parsing ───────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only) CHECK_ONLY=1; shift ;;
    --path)       INPUT_PATH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# ── resolve path ───────────────────────────────────────────────────────────────

# Priority: env var → stdin → flag
if [[ -z "$INPUT_PATH" ]]; then
  if [[ -n "${OPENCODE_TOOL_INPUT_PATH:-}" ]]; then
    INPUT_PATH="$OPENCODE_TOOL_INPUT_PATH"
  elif [[ ! -t 0 ]]; then
    # Read from stdin
    INPUT_PATH="$(cat)"
  fi
fi

if [[ -z "$INPUT_PATH" ]]; then
  echo "WARN: no path provided — nothing to check" >&2
  exit 0
fi

# ── check ──────────────────────────────────────────────────────────────────────

if _is_pat_path "$INPUT_PATH"; then
  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    echo "WARN: path matches PAT pattern: ${INPUT_PATH}" >&2
    exit 0
  else
    cat >&2 <<EOF
BLOCK: write to PAT file path rejected.
  Path : ${INPUT_PATH}
  Rule : SPEC-SE-036 Slice 2 + CLAUDE.md Rule #1
  Fix  : Store credentials in SAVIA_AGENT_API_KEY env var, not in files.
         Use: bash scripts/jwt-mint.sh mint <key_prefix> to get a short-lived JWT.
EOF
    exit 2
  fi
fi

exit 0
