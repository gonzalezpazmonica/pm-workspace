#!/usr/bin/env bash
# pre-output-validator.sh — TTSR-inspired pre-output rule validator (SE-150)
#
# Validates the content of Write/Edit/Bash tool calls against a set of regex
# patterns defined in docs/rules/domain/pre-output-rules.md BEFORE the output
# is persisted to disk.
#
# TTSR adaptation for Savia:
#   - Input: JSON from Claude Code PreToolUse hook (stdin) OR raw text (stdin)
#   - Output:
#       block  → exit 2, human-readable message to stderr
#       remind → exit 0, JSON {"reminder": "..."} to stdout (hook framework injects)
#       ok     → exit 0, silent
#
# Environment controls:
#   PRE_OUTPUT_RULES_ENABLED=false          → disable entirely (default: true)
#   PRE_OUTPUT_SEVERITY_OVERRIDE=remind     → degrade all 'block' to 'remind'
#   PRE_OUTPUT_SKIP_RULES=POR-001,POR-004   → comma-separated list to skip
#
# Usage (hook):
#   Registered as PreToolUse in .claude/settings.json
#   Receives JSON on stdin: {"tool_name": "Bash|Write|Edit", "tool_input": {...}}
#
# Usage (standalone / test):
#   echo 'content to check' | bash scripts/pre-output-validator.sh
#   bash scripts/pre-output-validator.sh < file.txt
#   bash scripts/pre-output-validator.sh --content "literal string"
#
# Exit codes:
#   0  — ok (or remind: reminder JSON on stdout)
#   2  — block: violation detected, message on stderr

set -uo pipefail

# ── Configuration ────────────────────────────────────────────────────────────

ENABLED="${PRE_OUTPUT_RULES_ENABLED:-true}"
SEVERITY_OVERRIDE="${PRE_OUTPUT_SEVERITY_OVERRIDE:-}"
SKIP_RULES="${PRE_OUTPUT_SKIP_RULES:-}"

if [[ "$ENABLED" == "false" ]]; then
  exit 0
fi

# ── Read input ────────────────────────────────────────────────────────────────

CONTENT=""
TOOL_NAME=""
IS_JSON=false

# Check for --content flag (standalone mode)
if [[ "${1:-}" == "--content" ]]; then
  CONTENT="${2:-}"
else
  # Read stdin (hook mode or pipe mode)
  RAW_INPUT=""
  if RAW_INPUT=$(timeout 5 cat 2>/dev/null); then
    :
  fi

  if [[ -z "$RAW_INPUT" ]]; then
    exit 0
  fi

  # Try to parse as JSON (hook mode)
  if command -v jq &>/dev/null; then
    TOOL_NAME=$(printf '%s' "$RAW_INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || TOOL_NAME=""

    if [[ -n "$TOOL_NAME" ]]; then
      IS_JSON=true
      case "$TOOL_NAME" in
        Bash)
          CONTENT=$(printf '%s' "$RAW_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || CONTENT=""
          ;;
        Write)
          CONTENT=$(printf '%s' "$RAW_INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null) || CONTENT=""
          ;;
        Edit)
          # Check both new_string and content fields
          CONTENT=$(printf '%s' "$RAW_INPUT" | jq -r '(.tool_input.new_string // .tool_input.content // empty)' 2>/dev/null) || CONTENT=""
          ;;
        *)
          # Unknown tool: pass through
          exit 0
          ;;
      esac
    else
      # Not JSON: treat raw input as content (standalone/pipe mode)
      CONTENT="$RAW_INPUT"
      TOOL_NAME="raw"
    fi
  else
    # No jq: treat as raw content
    CONTENT="$RAW_INPUT"
    TOOL_NAME="raw"
  fi
fi

if [[ -z "$CONTENT" ]]; then
  exit 0
fi

# ── Rule evaluation engine ────────────────────────────────────────────────────

_is_skipped() {
  local rule_id="$1"
  [[ -z "$SKIP_RULES" ]] && return 1
  if echo "$SKIP_RULES" | grep -q "$rule_id"; then
    return 0
  fi
  return 1
}

_effective_severity() {
  local severity="$1"
  if [[ "$SEVERITY_OVERRIDE" == "remind" ]]; then
    echo "remind"
  else
    echo "$severity"
  fi
}

_emit_remind() {
  local rule_id="$1"
  local message="$2"
  local json_msg
  json_msg=$(printf '%s' "$message" | sed 's/"/\\"/g')
  printf '{"reminder": "[%s] %s"}\n' "$rule_id" "$json_msg"
}

_emit_block() {
  local rule_id="$1"
  local message="$2"
  printf 'BLOQUEADO [%s]: %s\n' "$rule_id" "$message" >&2
}

VIOLATIONS=0
REMINDERS=""

_check_rule() {
  local rule_id="$1"
  local pattern="$2"
  local scope="$3"
  local severity="$4"
  local message="$5"

  # Skip if in skip list
  _is_skipped "$rule_id" && return 0

  # Scope check: if tool_name set, verify scope matches
  if [[ "$TOOL_NAME" != "raw" && "$TOOL_NAME" != "" ]]; then
    local scope_match=false
    if [[ "$scope" == "*" ]]; then
      scope_match=true
    fi
    # Check each scope entry (comma-separated)
    IFS=',' read -ra SCOPE_PARTS <<< "$scope"
    for sc in "${SCOPE_PARTS[@]}"; do
      sc_trimmed="${sc// /}"
      case "$sc_trimmed" in
        write) [[ "$TOOL_NAME" == "Write" ]] && scope_match=true ;;
        edit)  [[ "$TOOL_NAME" == "Edit"  ]] && scope_match=true ;;
        bash)  [[ "$TOOL_NAME" == "Bash"  ]] && scope_match=true ;;
        *)     true ;;
      esac
    done
    [[ "$scope_match" == "false" ]] && return 0
  fi

  # Pattern match
  if printf '%s' "$CONTENT" | grep -qE "$pattern" 2>/dev/null; then
    local eff_severity
    eff_severity=$(_effective_severity "$severity")

    if [[ "$eff_severity" == "block" ]]; then
      _emit_block "$rule_id" "$message"
      VIOLATIONS=$((VIOLATIONS + 1))
    else
      # remind: accumulate
      local reminder
      reminder=$(_emit_remind "$rule_id" "$message")
      REMINDERS="${REMINDERS}${reminder}"$'\n'
    fi
  fi
}

# ── Rule definitions ─────────────────────────────────────────────────────────
# Format: _check_rule ID PATTERN SCOPE SEVERITY MESSAGE

# POR-001: Hardcoded PAT/token
_check_rule "POR-001" \
  "(ghp_[A-Za-z0-9]{36}|ado_[A-Za-z0-9]{52}|AKIA[0-9A-Z]{16})" \
  "write,edit,bash" \
  "block" \
  "PAT/token hardcodeado detectado. Usa \$(cat \$PAT_FILE) o vault. Ref: Rule #1"

# POR-002: CLAUDE_PROJECT_DIR usage (should be SAVIA_WORKSPACE_DIR)
_check_rule "POR-002" \
  '\$CLAUDE_PROJECT_DIR\b' \
  "write,edit" \
  "remind" \
  "Usa \$SAVIA_WORKSPACE_DIR (via scripts/savia-env.sh). CLAUDE_PROJECT_DIR es vacío bajo OpenCode. Ref: SPEC-127"

# POR-003: git commit directly on main/master
_check_rule "POR-003" \
  "(checkout[[:space:]]+(main|master)[[:space:]]*&&[[:space:]]*git[[:space:]]+commit|git[[:space:]]+commit.*#[[:space:]]*(on[[:space:]]+)?branch[[:space:]]*(main|master)|git[[:space:]]+switch[[:space:]]+(main|master).*&&.*git[[:space:]]+commit)" \
  "bash" \
  "block" \
  "git commit directo en main/master detectado. Crea una feature branch. Ref: Rule #13"

# POR-004: terraform apply without explicit test/help flags
_check_rule "POR-004" \
  "terraform[[:space:]]+apply([^-]|$)" \
  "bash,write,edit" \
  "block" \
  "terraform apply requiere aprobacion humana. Solo permitido en DEV con confirmacion explicita. Ref: Rule #10"

# POR-005: rm -rf on dangerous paths (not /tmp)
_check_rule "POR-005" \
  "rm[[:space:]]+-[rf]{1,2}[[:space:]]+/([^t]|t[^m]|tm[^p]|tmp[^/[:space:]])" \
  "bash" \
  "block" \
  "rm -rf con ruta peligrosa (no /tmp). Verifica el path antes de ejecutar."

# POR-006: inline credential assignment
_check_rule "POR-006" \
  "(password|passwd|secret|api_key)[[:space:]]*=[[:space:]]*[\"'][^\"']{6,}[\"']" \
  "write,edit,bash" \
  "block" \
  "Credencial inline detectada. Usa variables de entorno o vault. Ref: Rule #9"

# POR-007: git push --force (without -with-lease)
_check_rule "POR-007" \
  "git[[:space:]]+push[[:space:]]+(.*[[:space:]])?--force([[:space:]]|$)" \
  "bash" \
  "block" \
  "git push --force detectado. Usa --force-with-lease o crea rama agent/*. Ref: Rule #13 + autonomous-safety"

# ── Emit results ──────────────────────────────────────────────────────────────

# If any reminders accumulated, emit them (exit 0)
if [[ -n "$REMINDERS" ]]; then
  printf '%s' "$REMINDERS"
fi

# If any blocks, exit 2
if [[ $VIOLATIONS -gt 0 ]]; then
  exit 2
fi

exit 0
