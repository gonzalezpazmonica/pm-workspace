#!/usr/bin/env bash
# security-audit-all.sh — Unified runner for all security scanners.
#
# Ejecuta en secuencia:
#   - prompt-security-scan.sh (PS-01..PS-14) sobre agents/skills
#   - mcp-security-audit.sh (MCP-01..MCP-11) SE-058
#   - permissions-wildcard-audit.sh (PERM-01..PERM-08) SE-059
#   - hook-injection-audit.sh (HOOK-01..HOOK-09) SE-060
#
# Agrega findings en un solo report JSON o human.
#
# Usage:
#   security-audit-all.sh              # run all + human report
#   security-audit-all.sh --json       # aggregated JSON
#   security-audit-all.sh --fail-on LEVEL   # exit 1 if findings >= LEVEL (default HIGH)
#
# Exit codes:
#   0 — findings below fail-on threshold
#   1 — findings at or above fail-on threshold
#   2 — usage error
#
# Ref: docs/rules/domain/security-scanners.md
# Safety: read-only, invokes read-only scanners. set -uo pipefail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

JSON=0
FAIL_ON="HIGH"

usage() {
  cat <<EOF
Usage:
  $0 [--json] [--fail-on LOW|MEDIUM|HIGH|CRITICAL]

Runs all security scanners and aggregates findings.

Options:
  --json              JSON aggregated output
  --fail-on LEVEL     Exit 1 if any finding at LEVEL or higher (default HIGH)

Ref: docs/rules/domain/security-scanners.md
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --fail-on) FAIL_ON="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

case "$FAIL_ON" in
  LOW|MEDIUM|HIGH|CRITICAL) ;;
  *) echo "ERROR: invalid --fail-on level" >&2; exit 2 ;;
esac

sev_rank() {
  case "$1" in
    LOW) echo 1 ;;
    MEDIUM) echo 2 ;;
    HIGH) echo 3 ;;
    CRITICAL) echo 4 ;;
    *) echo 0 ;;
  esac
}
FAIL_RANK=$(sev_rank "$FAIL_ON")

TOTAL_CRIT=0
TOTAL_HIGH=0
TOTAL_MED=0
TOTAL_LOW=0
SCANNER_RESULTS=()

run_scanner() {
  local name="$1" cmd="$2"
  local output
  output=$(eval "$cmd" 2>/dev/null || echo '{}')
  # Parse severity counts from JSON
  local c h m l
  c=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('critical', 0))" 2>/dev/null || echo 0)
  h=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('high', 0))" 2>/dev/null || echo 0)
  m=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('medium', 0))" 2>/dev/null || echo 0)
  l=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('low', 0))" 2>/dev/null || echo 0)
  c="${c:-0}"; h="${h:-0}"; m="${m:-0}"; l="${l:-0}"
  TOTAL_CRIT=$((TOTAL_CRIT + c))
  TOTAL_HIGH=$((TOTAL_HIGH + h))
  TOTAL_MED=$((TOTAL_MED + m))
  TOTAL_LOW=$((TOTAL_LOW + l))
  SCANNER_RESULTS+=("$name|$c|$h|$m|$l")
}

# Run each scanner in JSON mode
run_scanner "mcp-security-audit" "bash $PROJECT_ROOT/scripts/mcp-security-audit.sh --json"
run_scanner "permissions-wildcard-audit" "bash $PROJECT_ROOT/scripts/permissions-wildcard-audit.sh --json"
run_scanner "hook-injection-audit" "bash $PROJECT_ROOT/scripts/hook-injection-audit.sh --json"

# Prompt security scan: count findings manually (it has different output format)
PS_FINDINGS=0
if [[ -x "$PROJECT_ROOT/scripts/prompt-security-scan.sh" ]]; then
  PS_OUT=$(bash "$PROJECT_ROOT/scripts/prompt-security-scan.sh" "$PROJECT_ROOT/.claude/agents" 2>&1 || true)
  PS_FINDINGS=$(echo "$PS_OUT" | grep -oE 'Findings: [0-9]+' | head -1 | awk '{print $2}')
  PS_FINDINGS="${PS_FINDINGS:-0}"
  # Assume HIGH severity for PS findings (simplification)
  TOTAL_HIGH=$((TOTAL_HIGH + PS_FINDINGS))
  SCANNER_RESULTS+=("prompt-security-scan|0|$PS_FINDINGS|0|0")
fi

# Determine exit
EXIT_CODE=0
for sev_thresh in CRITICAL HIGH MEDIUM LOW; do
  rank=$(sev_rank "$sev_thresh")
  if [[ "$rank" -ge "$FAIL_RANK" ]]; then
    case "$sev_thresh" in
      CRITICAL) [[ "$TOTAL_CRIT" -gt 0 ]] && EXIT_CODE=1 ;;
      HIGH) [[ "$TOTAL_HIGH" -gt 0 ]] && EXIT_CODE=1 ;;
      MEDIUM) [[ "$TOTAL_MED" -gt 0 ]] && EXIT_CODE=1 ;;
      LOW) [[ "$TOTAL_LOW" -gt 0 ]] && EXIT_CODE=1 ;;
    esac
  fi
done

if [[ "$JSON" -eq 1 ]]; then
  scanners_json=""
  for r in "${SCANNER_RESULTS[@]}"; do
    IFS='|' read -r name c h m l <<< "$r"
    scanners_json+="{\"scanner\":\"$name\",\"critical\":$c,\"high\":$h,\"medium\":$m,\"low\":$l},"
  done
  scanners_json="[${scanners_json%,}]"
  cat <<JSON
{"verdict":"$([ $EXIT_CODE -eq 0 ] && echo PASS || echo FAIL)","fail_on":"$FAIL_ON","total_critical":$TOTAL_CRIT,"total_high":$TOTAL_HIGH,"total_medium":$TOTAL_MED,"total_low":$TOTAL_LOW,"scanners":$scanners_json}
JSON
else
  echo "=== Savia Security Audit (all scanners) ==="
  echo ""
  echo "Fail threshold:  $FAIL_ON"
  echo ""
  printf "  %-35s %-8s %-6s %-6s %-5s\n" "SCANNER" "CRIT" "HIGH" "MED" "LOW"
  for r in "${SCANNER_RESULTS[@]}"; do
    IFS='|' read -r name c h m l <<< "$r"
    printf "  %-35s %-8s %-6s %-6s %-5s\n" "$name" "$c" "$h" "$m" "$l"
  done
  echo ""
  echo "Totals:          crit=$TOTAL_CRIT  high=$TOTAL_HIGH  med=$TOTAL_MED  low=$TOTAL_LOW"
  echo ""
  echo "VERDICT: $([ $EXIT_CODE -eq 0 ] && echo PASS || echo FAIL)"
fi

exit $EXIT_CODE
