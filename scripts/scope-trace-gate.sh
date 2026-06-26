#!/usr/bin/env bash
# scope-trace-gate.sh — G13 Scope-trace gate (standalone runner)
set -uo pipefail
# SE-079: verifica que los ficheros modificados trazán al scope declarado en la spec/task.
#
# Uso:
#   bash scripts/scope-trace-gate.sh [--spec SE-079] [--files file1 file2 ...]
#   bash scripts/scope-trace-gate.sh --spec SE-079   # usa git diff --name-only automáticamente
#   bash scripts/scope-trace-gate.sh                 # sin spec → exit 0 (graceful)
#
# Output: JSON a stdout
#   {
#     "gate": "G13-SCOPE-TRACE",
#     "passed": bool,
#     "spec_id": "SE-XXX" | null,
#     "files_in_scope": [...],
#     "files_outside_scope": [...],
#     "verdict": "PASS" | "WARN" | "SKIP"
#   }
#
# Exit codes:
#   0 — siempre (el gate AVISA pero nunca bloquea)
#
# Spec: docs/propuestas/SE-079-pr-plan-scope-trace-gate.md
# Pattern: Genesis B9 GOAL STEWARD + B8 ATTENTION ANCHOR (SE-080)
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Parse args ────────────────────────────────────────────────────────────────
SPEC_ID=""
declare -a INPUT_FILES=()
PARSE_FILES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec)   SPEC_ID="$2"; shift 2 ;;
    --files)  PARSE_FILES=1; shift ;;
    --*)      shift ;;                 # ignore unknown flags
    *)
      if [[ "$PARSE_FILES" -eq 1 ]]; then
        INPUT_FILES+=("$1"); shift
      else
        shift
      fi
      ;;
  esac
done

# ── Emit JSON helper ──────────────────────────────────────────────────────────
emit_json() {
  local passed_py="$1" verdict="$2" in_scope_json="$3" out_scope_json="$4" spec_val="$5"
  python3 - <<PYEOF
import json
print(json.dumps({
    'gate': 'G13-SCOPE-TRACE',
    'passed': ${passed_py},
    'spec_id': ${spec_val},
    'files_in_scope': ${in_scope_json},
    'files_outside_scope': ${out_scope_json},
    'verdict': '${verdict}'
}, indent=2))
PYEOF
}

# ── No spec provided → graceful skip ─────────────────────────────────────────
if [[ -z "$SPEC_ID" ]]; then
  emit_json "True" "SKIP" "[]" "[]" "None"
  exit 0
fi

# ── Collect files (from --files or git diff) ─────────────────────────────────
if [[ "${#INPUT_FILES[@]}" -eq 0 ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && INPUT_FILES+=("$line")
  done < <(git -C "$REPO_ROOT" diff --name-only 2>/dev/null || true)
fi

if [[ "${#INPUT_FILES[@]}" -eq 0 ]]; then
  emit_json "True" "SKIP" "[]" "[]" "\"${SPEC_ID}\""
  exit 0
fi

# ── Locate spec file ──────────────────────────────────────────────────────────
SPEC_FILE=""
SPEC_FILE=$(find "$REPO_ROOT/docs/propuestas" -maxdepth 1 -type f -name "${SPEC_ID}*.md" 2>/dev/null | head -1 || true)

if [[ -z "$SPEC_FILE" ]]; then
  # Spec not found → warn but never fail
  FILES_JSON=$(printf '%s\n' "${INPUT_FILES[@]}" | python3 -c "import json,sys; print(json.dumps([l.rstrip() for l in sys.stdin if l.strip()]))")
  emit_json "True" "WARN" "$FILES_JSON" "[]" "\"${SPEC_ID}\""
  exit 0
fi

# ── Extract scope tokens from spec ───────────────────────────────────────────

# 1. AC tokens (lines matching `- [ ] AC-XX` or `- [x] AC-XX`)
AC_TOKENS=$(grep -E '^- \[[ x]\] AC-' "$SPEC_FILE" 2>/dev/null \
  | tr '[:upper:]' '[:lower:]' \
  | tr -c '[:alnum:]_\n-' ' ' \
  | tr ' ' '\n' \
  | awk 'length($0) >= 4' \
  | sort -u || true)

# 2. Explicit path hints mentioned in spec body
PATH_HINTS=$(grep -oE '[a-zA-Z0-9_./-]+\.(sh|py|md|bats|json|yaml|yml|ts|tsx|js)' "$SPEC_FILE" 2>/dev/null \
  | grep -v '^$' | sort -u || true)

# ── Whitelist (always in-scope) ───────────────────────────────────────────────
is_whitelisted() {
  local f="$1"
  case "$f" in
    CHANGELOG.md|CHANGELOG.d/*|.scm/*|.confidentiality-signature|.pr-summary.md) return 0 ;;
  esac
  return 1
}

# ── Spec self-reference ───────────────────────────────────────────────────────
SPEC_PREFIX="docs/propuestas/${SPEC_ID}"

# ── Evaluate each file ────────────────────────────────────────────────────────
declare -a IN_SCOPE=()
declare -a OUT_SCOPE=()

for f in "${INPUT_FILES[@]}"; do
  [[ -z "$f" ]] && continue

  # Whitelist
  if is_whitelisted "$f"; then
    IN_SCOPE+=("$f"); continue
  fi

  # Self-spec match
  if [[ "$f" == "${SPEC_PREFIX}"* ]]; then
    IN_SCOPE+=("$f"); continue
  fi

  # Path hint match (exact substring)
  if [[ -n "$PATH_HINTS" ]] && echo "$PATH_HINTS" | grep -Fq "$(basename "$f")"; then
    IN_SCOPE+=("$f"); continue
  fi

  # Token overlap on basename
  local_base=$(basename "$f" | sed -E 's/\.[a-z]+$//' | tr '[:upper:]' '[:lower:]')
  matched=0
  if [[ -n "$AC_TOKENS" ]]; then
    # Whole-basename match
    if echo "$AC_TOKENS" | grep -Fxq "$local_base"; then
      matched=1
    else
      # Per-token match (split on - and _)
      for tok in $(echo "$local_base" | tr '_-' '\n\n' | awk 'length($0) >= 4'); do
        if echo "$AC_TOKENS" | grep -Fxq "$tok" || echo "$AC_TOKENS" | grep -Fq "$tok"; then
          matched=1; break
        fi
      done
    fi
  fi

  if [[ "$matched" -eq 1 ]]; then
    IN_SCOPE+=("$f")
  else
    OUT_SCOPE+=("$f")
  fi
done

# ── Build output ──────────────────────────────────────────────────────────────
SPEC_VAL="\"${SPEC_ID}\""
_to_json_array() {
  printf '%s\n' "$@" | python3 -c "import json,sys; print(json.dumps([l.rstrip() for l in sys.stdin if l.strip()]))"
}
IN_JSON=$(_to_json_array "${IN_SCOPE[@]:-_placeholder_}" | python3 -c "import json,sys; arr=json.load(sys.stdin); print(json.dumps([x for x in arr if x != '_placeholder_']))")
OUT_JSON=$(_to_json_array "${OUT_SCOPE[@]:-_placeholder_}" | python3 -c "import json,sys; arr=json.load(sys.stdin); print(json.dumps([x for x in arr if x != '_placeholder_']))")

if [[ "${#OUT_SCOPE[@]}" -gt 0 ]]; then
  # Files outside scope → WARN (never FAIL — gate is advisory only per SE-079)
  emit_json "False" "WARN" "$IN_JSON" "$OUT_JSON" "$SPEC_VAL"
else
  emit_json "True" "PASS" "$IN_JSON" "[]" "$SPEC_VAL"
fi

exit 0
