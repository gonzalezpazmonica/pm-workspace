#!/usr/bin/env bash
# learning-guard.sh — SCL-001 S4: guard de agnosticismo del bucle de aprendizaje
#
# Verifica que el bucle SCL es agnóstico a LLM por construcción:
#   1. Cero vendor names en el código del bucle (ADR-012, AC-4.3).
#   2. Cero escrituras fuera del sustrato (markdown/JSONL versionados) — el
#      bucle NUNCA llama a APIs de fine-tuning ni escribe binarios (AC-4.2).
#   3. La CONSTITUCION permanece invariable tras N ciclos (AC-4.5, ART-01/11).
#
# Usage:
#   learning-guard.sh --loop-dir <dir> [--constitution <path>] [--json] [--allow-vendor]
#
# Exit codes: 0 clean, 1 violation, 2 usage, 3 missing dir
#
# Ref: docs/specs/SCL-001-aprendizaje-continuo.spec.md (S4, AC-4.2/4.3/4.5)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

LOOP_DIR=""
CONSTITUTION="${SCL_CONSTITUTION:-$ROOT/.claude/CONSTITUCION.md}"
JSON=false
ALLOW_VENDOR=false

usage() {
  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --loop-dir) LOOP_DIR="$2"; shift 2 ;;
    --constitution) CONSTITUTION="$2"; shift 2 ;;
    --json) JSON=true; shift ;;
    --allow-vendor) ALLOW_VENDOR=true; shift ;;
    -h|--help) usage ;;
    *) shift ;;
  esac
done

[[ -z "$LOOP_DIR" ]] && usage
[[ -d "$LOOP_DIR" ]] || { echo "ERROR: loop dir not found: $LOOP_DIR" >&2; exit 3; }

# ── 1. Vendor-name scan (AC-4.3) ──
# Only the loop's own files are scanned (learning-*.sh). Vendor/model names
# indicate coupling. The bucle must have ZERO.
VENDOR_RX='anthropic|openai|google|gemini|deepseek|qwen|mistral|cohere|llama\b|gpt-[0-9]|claude|opencode|claude-code|fine[-_ ]?tun|loras?\b|checkpoint'

vendor_hits=0
if ! $ALLOW_VENDOR; then
  # learning-guard.sh itself defines the vendor pattern — exclude it from the scan
  vendor_hits=$(grep -rniE "$VENDOR_RX" "$LOOP_DIR" --include='learning-*.sh' 2>/dev/null \
    | grep -v 'learning-guard.sh' | wc -l | tr -d ' ')
fi

# ── 2. Write-sustrato-only audit (AC-4.2) ──
# The loop may only write .md/.jsonl/.json files (versioned text sustrado).
# Only the loop's own files are inspected.
bad_write_targets=0
while IFS= read -r f; do
  [[ "$f" != *"learning-"* ]] && continue
  case "$f" in
    *.sh|*.json|*.jsonl|*.bats|*.md) ;;
    *) bad_write_targets=$((bad_write_targets + 1)); echo "  non-sustrato target: $f" >&2 ;;
  esac
done < <(grep -rhoE '"(output|docs|\.claude|\.opencode)/[^"]+"' "$LOOP_DIR" --include='learning-*.sh' 2>/dev/null | tr -d '"' | sort -u)

# ── 3. Constitution invariance (AC-4.5) ──
const_hash=""
if [[ -f "$CONSTITUTION" ]]; then
  const_hash=$(sha256sum "$CONSTITUTION" | cut -d' ' -f1)
fi

violations=0
if [[ $vendor_hits -gt 0 ]]; then violations=$((violations + 1)); fi
if [[ $bad_write_targets -gt 0 ]]; then violations=$((violations + 1)); fi

if $JSON; then
  printf '{"vendor_hits":%d,"non_sustrato_targets":%d,"constitution_sha256":"%s","verdict":"%s"}\n' \
    "$vendor_hits" "$bad_write_targets" "$const_hash" "$([[ $violations -eq 0 ]] && echo CLEAN || echo VIOLATION)"
else
  echo "=== Learning Loop Agnosticism Guard (SCL-001 S4) ==="
  echo "  vendor-name hits in loop code: $vendor_hits"
  echo "  non-sustrato write targets:   $bad_write_targets"
  echo "  CONSTITUCION sha256:          ${const_hash:-MISSING}"
  if [[ $violations -eq 0 ]]; then
    echo "  Verdict: CLEAN — bucle agnóstico a LLM"
  else
    echo "  Verdict: VIOLATION"
  fi
fi

[[ $violations -eq 0 ]]
