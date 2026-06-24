#!/usr/bin/env bash
# block-pat-file-write.sh — SPEC-SE-036 Slice 3: PreToolUse hook — bloquea writes a paths PAT/token/secret
# Hook: PreToolUse matcher Write|Edit
# Master switch: SAVIA_PAT_BLOCK=on|off (default on — es seguridad, no opt-in)
# Ref: docs/rules/domain/savia-enterprise/agent-jwt-mint.md
# Ref: CLAUDE.md Rule #1
set -uo pipefail

# ── Master switch ─────────────────────────────────────────────────────────────
SAVIA_PAT_BLOCK="${SAVIA_PAT_BLOCK:-on}"
if [[ "$SAVIA_PAT_BLOCK" != "on" ]]; then
  exit 0
fi

# ── Parse input ───────────────────────────────────────────────────────────────
# Hook input arrives as JSON on stdin OR via --path CLI argument (tests).
INPUT_PATH=""
CLI_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path) CLI_PATH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -n "$CLI_PATH" ]]; then
  INPUT_PATH="$CLI_PATH"
else
  # Read JSON from stdin, extract file_path
  INPUT=""
  if INPUT=$(timeout 3 cat 2>/dev/null); then
    :
  fi
  if [[ -n "$INPUT" ]] && command -v jq &>/dev/null; then
    INPUT_PATH=$(printf '%s' "$INPUT" | jq -r '
      .tool_input.file_path //
      .tool_input.path //
      empty' 2>/dev/null) || INPUT_PATH=""
  fi
fi

# No path → nothing to check
if [[ -z "$INPUT_PATH" ]]; then
  exit 0
fi

# ── Exceptions: test files and docs are always allowed ───────────────────────
_is_exception() {
  local path="$1"
  # Normalize
  local lower
  lower="$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')"
  # tests/ directory — any path containing /tests/
  case "$lower" in
    *tests/*) return 0 ;;
    *test-*)  return 0 ;;
    *.bats)   return 0 ;;
  esac
  # docs/ directory
  case "$lower" in
    *docs/*) return 0 ;;
  esac
  # scripts/*.bats test files
  case "$lower" in
    */scripts/*.bats) return 0 ;;
  esac
  return 1
}

# ── Check .gitignore ──────────────────────────────────────────────────────────
_is_gitignored() {
  local path="$1"
  # Use git check-ignore if available and inside a git repo
  if command -v git &>/dev/null; then
    if git -C "$(dirname "$path" 2>/dev/null || echo .)" check-ignore -q "$path" 2>/dev/null; then
      return 0
    fi
    # Also check common gitignored patterns from workspace root
    if git check-ignore -q "$path" 2>/dev/null; then
      return 0
    fi
  fi
  # Fallback: check if path is under known gitignored dirs
  local lower
  lower="$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    */\.savia/*|~/.savia/*) return 0 ;;
    */\.azure/*|~/.azure/*) return 0 ;;
    */.secrets/*|*/secrets/*) return 0 ;;
    */pm-config.local*) return 0 ;;
  esac
  return 1
}

# ── Sensitive path detection ──────────────────────────────────────────────────
_is_sensitive_path() {
  local path="$1"
  local basename
  basename="$(basename "$path" | tr '[:upper:]' '[:lower:]')"
  local lower
  lower="$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')"

  # Match "pat" in filename
  case "$basename" in
    *pat*) return 0 ;;
  esac
  # Match "pat" in path component (e.g. /azure/devops-pat)
  case "$lower" in
    *-pat|*-pat.*|*/pat|*/pat.*|*_pat|*_pat.*) return 0 ;;
  esac
  # Match "token" or "secret" in basename (credential-type names)
  case "$basename" in
    *token*|*secret*) return 0 ;;
  esac
  return 1
}

# ── Main logic ────────────────────────────────────────────────────────────────

# Exception: test/docs paths always allowed
if _is_exception "$INPUT_PATH"; then
  exit 0
fi

# Exception: gitignored paths allowed (credentials live there by design)
if _is_gitignored "$INPUT_PATH"; then
  exit 0
fi

# Check for sensitive filename patterns
if _is_sensitive_path "$INPUT_PATH"; then
  cat >&2 <<EOF
BLOCK [SPEC-SE-036 Slice 3]: write to sensitive credential path rejected.
  Path  : ${INPUT_PATH}
  Rule  : CLAUDE.md Rule #1 — NUNCA hardcodear credenciales en paths versionados.
  Fix   : Store credentials in SAVIA_AGENT_API_KEY env var (off-repo vault).
          Use: bash scripts/jwt-mint.sh --key-stdin --scope <scope> to get a JWT.
  Bypass: SAVIA_PAT_BLOCK=off (temporal — reactivar tras resolver el bloqueante).
EOF
  exit 2
fi

exit 0
