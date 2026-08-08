#!/usr/bin/env bash
# standards-compliance-gate.sh — SE-311 S2: compuerta determinista de estandares
#
# Valida el diff FINAL (incluye ediciones manuales post-agente) contra los
# estandares de la organizacion, consolidando checks que antes vivian dispersos
# en la suite BATS. Determinista, re-ejecutable a mano, con --json y --report.
#
# Usage:
#   standards-compliance-gate.sh [--base <ref>] [--json] [--report <path>] [--check <name>]
#
# Checks (default todos):
#   file-size   docs/rules, comandos, agentes <= 150 lineas (excepciones doc)
#   skill-audit skill-catalog-audit.sh --json (fail == 0)
#   agent-schema agents-opencode-convert.sh --check (idempotente)
#   drift       claude-md-drift-check.sh + readme-drift + spec-status-drift
#   rules       validacion de reglas (resolucion de referencias minimas)
#   confid      confidentiality-scan.sh --pr (PII/confidencialidad)
#
# Exit: 0 = PASS, 1 = FAIL (con el check que fallo)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SLDC_GATE_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

BASE_REF=""; JSON=0; REPORT=""; ONLY=""
CHECKS=(file-size skill-audit agent-schema drift rules confid)

usage() { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE_REF="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    --report) REPORT="$2"; shift 2 ;;
    --check) ONLY="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "error: $1" >&2; usage ;;
  esac
done

RESULT=""; FAILED=""

# ── check: file-size ─────────────────────────────────────────────────────────
check_file_size() {
  local oversized=0 detail=""
  for f in "$ROOT"/.opencode/commands/*.md "$ROOT"/.opencode/agents/*.md "$ROOT"/docs/rules/domain/*.md; do
    [[ -f "$f" ]] || continue
    case "$(basename "$f")" in
      INDEX.md|savia-ethical-principles.md|enterprise-onboarding-protocol.md|enterprise-sovereign-deployment.md|meeting-participant-etiquette.md|portfolio-as-graph.en.md|meeting-digest.md|loop-state-schema.md|cross-frontend-coverage.md) continue ;;
    esac
    local lines; lines=$(wc -l < "$f")
    if [[ "$lines" -gt 150 ]]; then oversized=$((oversized+1)); detail="$detail $(basename "$f")($lines)"; fi
  done
  if [[ "$oversized" -eq 0 ]]; then echo "PASS"; else echo "FAIL: $oversized fichero(s) >150 lineas:$detail"; fi
}

# ── check: skill-audit ───────────────────────────────────────────────────────
check_skill_audit() {
  local out
  out=$("$SCRIPT_DIR/skill-catalog-audit.sh" --json 2>/dev/null)
  local fail; fail=$(echo "$out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('fail',1))" 2>/dev/null || echo 1)
  if [[ "$fail" == "0" ]]; then echo "PASS"; else echo "FAIL: skill-catalog-audit reporta $fail FAIL"; fi
}

# ── check: agent-schema ──────────────────────────────────────────────────────
check_agent_schema() {
  local out
  out=$("$SCRIPT_DIR/agents-opencode-convert.sh" --check 2>&1)
  if echo "$out" | grep -q "in sync"; then echo "PASS"; else echo "FAIL: $out" | head -1; fi
}

# ── check: drift ─────────────────────────────────────────────────────────────
check_drift() {
  local fails=""
  "$SCRIPT_DIR/claude-md-drift-check.sh" >/dev/null 2>&1 || fails="$fails claude-md"
  [[ -f "$SCRIPT_DIR/readme-drift-check.sh" ]] && { "$SCRIPT_DIR/readme-drift-check.sh" >/dev/null 2>&1 || fails="$fails readme"; }
  [[ -f "$SCRIPT_DIR/spec-status-drift-audit.sh" ]] && { "$SCRIPT_DIR/spec-status-drift-audit.sh" >/dev/null 2>&1 || fails="$fails spec-status"; }
  if [[ -z "$fails" ]]; then echo "PASS"; else echo "FAIL:$fails"; fi
}

# ── check: rules ─────────────────────────────────────────────────────────────
check_rules() {
  # Validacion minima: el CRITERIO/reglas clave referenciadas existen
  local missing=""
  [[ -f "$ROOT/docs/rules/domain/critical-rules-extended.md" ]] || missing="$missing critical-rules"
  [[ -f "$ROOT/docs/rules/domain/pm-config.md" ]] || missing="$missing pm-config"
  if [[ -z "$missing" ]]; then echo "PASS"; else echo "FAIL:$missing"; fi
}

# ── check: confid ────────────────────────────────────────────────────────────
check_confid() {
  local out
  out=$("$SCRIPT_DIR/confidentiality-scan.sh" --pr 2>&1 | tail -3)
  if echo "$out" | grep -qiE "CLEAN|PASSED"; then echo "PASS"; else echo "FAIL: scan de confidencialidad"; fi
}

run_check() {
  case "$1" in
    file-size) check_file_size ;;
    skill-audit) check_skill_audit ;;
    agent-schema) check_agent_schema ;;
    drift) check_drift ;;
    rules) check_rules ;;
    confid) check_confid ;;
  esac
}

# ── ejecutar ─────────────────────────────────────────────────────────────────
SELECTED=("${CHECKS[@]}")
if [[ -n "$ONLY" ]]; then
  valid=0; for c in "${CHECKS[@]}"; do [[ "$c" == "$ONLY" ]] && valid=1; done
  if [[ "$valid" == "0" ]]; then echo "error: check desconocido: $ONLY (validos: ${CHECKS[*]})" >&2; exit 2; fi
  SELECTED=("$ONLY")
fi

for c in "${SELECTED[@]}"; do
  R=$(run_check "$c")
  RESULT="${RESULT}${c}: ${R}"$'\n'
  if [[ "$R" != PASS* ]]; then FAILED="$FAILED $c"; fi
done

if [[ -n "$REPORT" ]]; then
  { echo "# Standards Compliance Gate — reporte"; echo ""; echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo ""; echo -e "$RESULT"; echo "VERDICT: ${FAILED:+FAIL}$([[ -z "$FAILED" ]] && echo PASS)"; } > "$REPORT"
fi

if [[ "$JSON" == "1" ]]; then
  python3 - "$RESULT" "$FAILED" <<'PY'
import json, sys
result, failed = sys.argv[1], sys.argv[2].strip()
checks = {}
for line in result.strip().split("\n"):
    if ": " in line:
        name, status = line.split(": ", 1)
        checks[name] = "PASS" if status.startswith("PASS") else "FAIL"
print(json.dumps({"verdict": "PASS" if not failed else "FAIL", "failed": failed.split() if failed else [], "checks": checks}, indent=2))
PY
else
  echo -e "$RESULT"
  if [[ -n "$FAILED" ]]; then echo "VERDICT: FAIL ($FAILED)"; else echo "VERDICT: PASS"; fi
fi

[[ -z "$FAILED" ]] && exit 0 || exit 1
