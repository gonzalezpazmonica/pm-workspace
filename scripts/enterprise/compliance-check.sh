#!/usr/bin/env bash
# compliance-check.sh — SPEC-SE-006 Workspace Compliance Validator
set -uo pipefail
#
# Valida el workspace contra frameworks regulatorios.
#
# Args:
#   --framework eu-ai-act|nis2|gdpr|dora  (default: all)
#   --tenant SLUG                         (optional, scopes the audit trail check)
#   --anchor HASH                         (optional, requires --tenant)
#   --output-file PATH                    (optional, write JSON to file)
#
# Output JSON:
#   {
#     "framework": "eu-ai-act",
#     "tenant": "all",          (o el slug de --tenant)
#     "assessed_at": "2026-06-24T...",
#     "score": 75,
#     "checks": [
#       {"rule": "model_cards_exist", "passed": true, "evidence": "...", "gap": null},
#       ...
#     ]
#   }
#
# Alcance honesto: es una revisión documental preliminar; no prueba eficacia
# operativa ni emite certificación. Un check solo aprueba con evidencia con
# contenido: documentos con al menos MIN_LINES líneas sustantivas (sin títulos,
# citas, separadores ni líneas vacías) y que tratan el tema del check
# (palabras clave), model cards con secciones Purpose y Limitations,
# postmortems no vacíos, manifiestos JSON que son objetos no vacíos y audit
# trails que pasan verify. Un fichero o directorio vacío no es evidencia. Las
# palabras clave siguen siendo una heurística: no juzgan la calidad del texto.
#
# Environment:
#   SAVIA_COMPLIANCE_ROOT         Workspace a evaluar (default: raíz del repo)
#   CLAUDE_ENTERPRISE_AUDIT_BASE  Base de trails (default: <root>/.claude/enterprise/audit)
#
# Reference: SPEC-SE-006 (docs/propuestas/savia-enterprise/SPEC-SE-006-governance-compliance.md)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SAVIA_COMPLIANCE_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# ── Helpers ──────────────────────────────────────────────────────────────────

usage() {
  cat <<'USAGE'
compliance-check.sh — SPEC-SE-006 Regulatory Compliance Validator

Usage:
  compliance-check.sh [--framework FRAMEWORK] [--tenant SLUG] [--output-file PATH]
  compliance-check.sh --help

Options:
  --framework  Framework to check: eu-ai-act, nis2, gdpr, dora (default: all)
  --tenant     Scope the audit trail check to this tenant's trail (its entries
               must belong to it). Without it every tenant trail must verify.
  --anchor     sha256 hash published earlier by chain-status (needs --tenant):
               the trail must still contain it. Without an anchor the evidence
               says so: truncation or full recomputation is not excluded.
  --output-file PATH  Write JSON output to file instead of stdout

Evidence rules: documents need >= 3 substantive lines and topic keywords;
empty files, empty directories and empty JSON (null, [], {}) never pass.

Output:
  JSON with {framework, score, checks: [{rule, passed, evidence, gap}]}

Exit codes:
  0  All checks passed with substantive evidence (score = 100)
  1  One or more checks failed
  2  Invalid arguments or output file not writable
USAGE
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 2; }

need_val() { [[ "$1" -ge 2 ]] || die "$2 requires a value"; }

FRAMEWORK="all"
TENANT="default"
TENANT_GIVEN=0
ANCHOR=""
OUTPUT_FILE=""
MIN_LINES=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --framework)   need_val $# "$1"; FRAMEWORK="$2";   shift 2 ;;
    --tenant)      need_val $# "$1"; TENANT="$2"; TENANT_GIVEN=1; shift 2 ;;
    --anchor)      need_val $# "$1"; ANCHOR="$2"; shift 2 ;;
    --output-file) need_val $# "$1"; OUTPUT_FILE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ "$TENANT" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] \
  || die "invalid --tenant '${TENANT}': use [A-Za-z0-9][A-Za-z0-9._-]{0,63}"
if [[ -n "$ANCHOR" ]]; then
  [[ "$TENANT_GIVEN" -eq 1 ]] || die "--anchor requires --tenant"
  [[ "${ANCHOR#sha256:}" =~ ^[0-9a-f]{64}$ ]] || die "--anchor must be a sha256 hex hash"
fi
TENANT_LABEL="all"
[[ "$TENANT_GIVEN" -eq 1 ]] && TENANT_LABEL="$TENANT"
case "$FRAMEWORK" in
  all|eu-ai-act|gdpr|nis2|dora) ;;
  *) die "unknown framework: ${FRAMEWORK}. Valid: eu-ai-act, gdpr, nis2, dora, all" ;;
esac

AUDIT_BASE="${CLAUDE_ENTERPRISE_AUDIT_BASE:-${ROOT_DIR}/.claude/enterprise/audit}"

# ── Check helpers ─────────────────────────────────────────────────────────────

CHECKS_JSON=""
TOTAL=0
PASSED=0

# Escapa para una cadena JSON: barra invertida, comillas y controles.
json_esc() {
  local v="$1"
  v="${v//\\/\\\\}"
  v="${v//\"/\\\"}"
  v="${v//[[:cntrl:]]/ }"
  printf '%s' "$v"
}

# 0 = objeto JSON no vacío (y con las claves no vacías pedidas),
# 1 = inválido o vacío (null, [], {}, clave vacía), 2 = sin python3 para analizar
json_object() {  # $1=fichero [$2...=claves que deben existir y no estar vacías]
  command -v python3 >/dev/null 2>&1 || return 2
  python3 - "$@" >/dev/null 2>&1 <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert isinstance(d, dict) and d
for k in sys.argv[2:]:
    assert d.get(k)
PY
}

# Líneas sustantivas: sin títulos, citas, separadores, comentarios ni vacías.
substantive_lines() {
  grep -cvE '^[[:space:]]*(#|>|---|<!--|$)' "$1" 2>/dev/null
}

# 0 = evidencia con contenido, 1 = no existe, 2 = hueca, 3 = no trata el tema
doc_evidence() {  # $1=fichero $2=regex de tema (ERE, sin distinguir mayúsculas)
  [[ -f "$1" ]] || return 1
  [[ "$(substantive_lines "$1")" -ge "$MIN_LINES" ]] || return 2
  grep -qiE "$2" "$1" || return 3
}

# Check de documento fijo: add_check según doc_evidence.
check_doc() {  # $1=rule $2=fichero $3=regex $4=descripción del tema $5=gap
  local rel="${2#"${ROOT_DIR}"/}"
  doc_evidence "$2" "$3"
  case $? in
    0) add_check "$1" "true" "${rel}: $(substantive_lines "$2") substantive lines covering ${4}" "" ;;
    1) add_check "$1" "false" "${rel} not found" "$5" ;;
    2) add_check "$1" "false" "${rel} is hollow (< ${MIN_LINES} substantive lines)" "$5" ;;
    *) add_check "$1" "false" "${rel} does not cover ${4}" "$5" ;;
  esac
}

# Primeros documentos de docs/ con contenido que tratan un tema (máx. 3).
docs_covering() {  # $1=regex
  local f found=()
  while IFS= read -r f; do
    doc_evidence "$f" "$1" && found+=("${f#"${ROOT_DIR}"/}")
    [[ "${#found[@]}" -ge 3 ]] && break
  done < <(find "${ROOT_DIR}/docs" -name "*.md" -type f 2>/dev/null | sort)
  [[ "${#found[@]}" -gt 0 ]] && printf '%s ' "${found[@]}"
  return 0
}

# Add a check result to CHECKS_JSON
add_check() {
  local rule="$1" passed="$2" evidence="$3" gap="$4"
  TOTAL=$(( TOTAL + 1 ))
  [[ "$passed" == "true" ]] && PASSED=$(( PASSED + 1 ))

  local sep=""
  [[ -n "$CHECKS_JSON" ]] && sep=","

  evidence="$(json_esc "$evidence")"
  gap="$(json_esc "$gap")"

  CHECKS_JSON="${CHECKS_JSON}${sep}
    {\"rule\":\"${rule}\",\"passed\":${passed},\"evidence\":\"${evidence}\",\"gap\":$([ "$passed" == "true" ] && echo "null" || echo "\"${gap}\"")}"
}

# ── Audit trail: existence + chain verification ───────────────────────────────

check_audit_trail() {
  local verifier="${SCRIPT_DIR}/governance-audit-trail.sh"
  [[ -f "$verifier" ]] || verifier="${ROOT_DIR}/scripts/enterprise/governance-audit-trail.sh"
  local trails=() t
  if [[ "$TENANT_GIVEN" -eq 1 ]]; then
    [[ -f "${AUDIT_BASE}/${TENANT}/audit-trail.jsonl" ]] && trails+=("${AUDIT_BASE}/${TENANT}/audit-trail.jsonl")
  elif [[ -d "$AUDIT_BASE" ]]; then
    # -L: un trail enlazado simbólicamente cuenta igual que con --tenant.
    while IFS= read -r t; do trails+=("$t"); done \
      < <(find -L "$AUDIT_BASE" -mindepth 2 -maxdepth 2 -name "audit-trail.jsonl" -type f 2>/dev/null | sort)
  fi

  if [[ "${#trails[@]}" -eq 0 ]]; then
    add_check "audit_trail_exists" "false" "No audit trails found in ${AUDIT_BASE}" \
      "Run governance-audit-trail.sh append to initialize the audit trail"
    return
  fi
  if [[ ! -f "$verifier" ]]; then
    add_check "audit_trail_exists" "false" "${#trails[@]} trail(s) found but governance-audit-trail.sh is missing: not verified" \
      "Restore scripts/enterprise/governance-audit-trail.sh to verify the chain"
    return
  fi

  local bad=() entries=0 out args
  for t in "${trails[@]}"; do
    # El tenant de cada entrada debe coincidir con su directorio.
    args=(verify --file "$t" --tenant "$(basename "$(dirname "$t")")")
    [[ -n "$ANCHOR" ]] && args+=(--anchor "$ANCHOR")
    if out="$(bash "$verifier" "${args[@]}" 2>&1)"; then
      entries=$(( entries + $(grep -c . "$t") ))
    else
      bad+=("${t#"${AUDIT_BASE}"/}: $(printf '%s' "$out" | grep -E 'TAMPERED|ANCHOR|EMPTY|ERROR' | head -1)")
    fi
  done
  if [[ "${#bad[@]}" -gt 0 ]]; then
    add_check "audit_trail_exists" "false" "${#bad[@]} of ${#trails[@]} trail(s) failed verification" \
      "Investigate before trusting the trail: ${bad[*]}"
  elif [[ -n "$ANCHOR" ]]; then
    add_check "audit_trail_exists" "true" "trail of ${TENANT} verified against anchor (${entries} entries)" ""
  else
    add_check "audit_trail_exists" "true" "${#trails[@]} audit trail(s) verified (${entries} entries) without anchor: truncation or full recomputation not excluded" ""
  fi
}

# ── EU AI Act checks ──────────────────────────────────────────────────────────

check_eu_ai_act() {
  local model_cards_dir="${ROOT_DIR}/.claude/enterprise/model-cards"

  # Check 1: model cards con contenido (secciones Purpose y Limitations)
  local cards=() hollow=() f
  [[ -d "$model_cards_dir" ]] && while IFS= read -r f; do cards+=("$f"); done \
    < <(find "$model_cards_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null | sort)
  for f in "${cards[@]}"; do
    if ! doc_evidence "$f" '.' || ! grep -qiE '^##+ *Purpose' "$f" || ! grep -qiE '^##+ *Limitations' "$f"; then
      hollow+=("$(basename "$f")")
    fi
  done
  if [[ "${#cards[@]}" -eq 0 ]]; then
    add_check "model_cards_exist" "false" "No model cards found in ${model_cards_dir}" \
      "Run model-card-generator.sh to generate AI Act model cards"
  elif [[ "${#hollow[@]}" -gt 0 ]]; then
    add_check "model_cards_exist" "false" "${#hollow[@]} of ${#cards[@]} model card(s) hollow or without Purpose/Limitations: ${hollow[*]:0:5}" \
      "Regenerate or complete them with model-card-generator.sh"
  else
    add_check "model_cards_exist" "true" "${#cards[@]} model cards with Purpose and Limitations in ${model_cards_dir}" ""
  fi

  # Check 2: audit trail exists AND verifies (an unverified trail is not evidence)
  check_audit_trail

  # Check 3-5: políticas con contenido sobre su tema
  check_doc "human_oversight_gate" "${ROOT_DIR}/docs/rules/domain/autonomous-safety.md" \
    'revisi[oó]n humana|human review|AUTONOMOUS_REVIEWER|reviewer' "human review of autonomous output" \
    "Document the human oversight gate in docs/rules/domain/autonomous-safety.md"
  check_doc "governance_protocol_exists" "${ROOT_DIR}/docs/rules/domain/enterprise-governance-protocol.md" \
    'audit trail' "the audit trail and governance gates" \
    "Document the governance protocol in docs/rules/domain/enterprise-governance-protocol.md"
  check_doc "bias_tests_documented" "${ROOT_DIR}/docs/rules/domain/equality-shield.md" \
    'bias|sesgo|contrafactual|counterfactual' "bias testing" \
    "Document bias testing in docs/rules/domain/equality-shield.md"
}

# ── GDPR checks ───────────────────────────────────────────────────────────────

check_gdpr() {
  # Check 1: PII handling documented (documentos con contenido sobre PII)
  local pii_docs
  pii_docs="$(docs_covering 'pii|personal data|datos personales|data protection')"
  if [[ -n "$pii_docs" ]]; then
    add_check "pii_handling_documented" "true" "PII handling covered in: ${pii_docs}" ""
  else
    add_check "pii_handling_documented" "false" "No substantive PII handling documentation found" \
      "Add PII handling policy to docs/rules/domain/"
  fi

  # Check 2: data retention policy (con un plazo concreto)
  check_doc "data_retention_policy" "${ROOT_DIR}/docs/rules/domain/savia-enterprise/audit-retention.md" \
    '[0-9]+ *(days|d[ií]as|years|a[nñ]os|months|meses)' "a concrete retention period" \
    "Document retention periods in docs/rules/domain/savia-enterprise/audit-retention.md"

  # Check 3: context placement / N1-N4 classification
  check_doc "data_classification_policy" "${ROOT_DIR}/docs/rules/domain/context-placement-confirmation.md" \
    'N4' "the N1-N4b classification levels" \
    "Document the N1-N4b classification in docs/rules/domain/context-placement-confirmation.md"
}

# ── NIS2 checks ───────────────────────────────────────────────────────────────

check_nis2() {
  # Check 1: incident log — al menos un postmortem con contenido
  local incident_dir="${ROOT_DIR}/output/postmortems" pm=() f
  [[ -d "$incident_dir" ]] && while IFS= read -r f; do
    doc_evidence "$f" '.' && pm+=("$f")
  done < <(find "$incident_dir" -name "*.md" -type f 2>/dev/null)
  if [[ "${#pm[@]}" -gt 0 ]]; then
    add_check "incident_log_exists" "true" "${#pm[@]} substantive postmortem(s) in ${incident_dir}" ""
  elif [[ -d "$incident_dir" ]]; then
    add_check "incident_log_exists" "false" "output/postmortems/ has no substantive postmortem" \
      "Record incidents in output/postmortems/ for NIS2 incident logging"
  else
    add_check "incident_log_exists" "false" "output/postmortems/ directory not found" \
      "Create output/postmortems/ for NIS2 incident logging"
  fi

  # Check 2: security posture documented (savia-shield.md o security*.md con contenido)
  local security_docs=()
  while IFS= read -r f; do
    doc_evidence "$f" 'secur|segur|threat|amenaza' && security_docs+=("${f#"${ROOT_DIR}"/}")
  done < <(find "${ROOT_DIR}/docs" \( -name "savia-shield.md" -o -name "security*.md" \) -type f 2>/dev/null | sort | head -5)
  if [[ "${#security_docs[@]}" -gt 0 ]]; then
    add_check "security_posture_documented" "true" "Security docs: ${security_docs[*]:0:2}" ""
  else
    add_check "security_posture_documented" "false" "No substantive security posture documentation found" \
      "Create docs/savia-shield.md or equivalent security posture document"
  fi

  # Check 3: patch/update policy
  local patch_policy
  patch_policy="$(docs_covering 'patch(ing)? policy|parche|security update|dependency update|actualizaci[oó]n de dependencias|vulnerab')"
  if [[ -n "$patch_policy" ]]; then
    add_check "patch_policy_documented" "true" "Patch policy covered in: ${patch_policy}" ""
  else
    add_check "patch_policy_documented" "false" "No substantive patch/update policy documentation found" \
      "Document dependency update and patching policy"
  fi
}

# ── DORA checks ───────────────────────────────────────────────────────────────

# $1=rule $2=fichero $3=etiqueta $4=gap si falta [$5...=claves obligatorias]
check_json_doc() {
  local rule="$1" file="$2" label="$3" gap="$4"; shift 4
  if [[ ! -f "$file" ]]; then
    add_check "$rule" "false" "${label} not found" "$gap"
    return
  fi
  json_object "$file" "$@"
  case $? in
    0) add_check "$rule" "true" "${label} is a non-empty JSON object${1:+ with non-empty: $*}" "" ;;
    1) add_check "$rule" "false" "${label} is not a non-empty JSON object${1:+ with non-empty: $*}" "Fix ${file}" ;;
    *) add_check "$rule" "false" "${label} present but not parsed (python3 unavailable)" \
         "Install python3 or validate ${file} manually" ;;
  esac
}

check_dora() {
  # Check 1: ICT risk register — manifest con módulos declarados
  check_json_doc "ict_risk_register" "${ROOT_DIR}/.claude/enterprise/manifest.json" \
    ".claude/enterprise/manifest.json" "Create .claude/enterprise/manifest.json with ICT risk register" modules

  # Check 2: GLM governance manifest (AI transparency / outsourcing)
  check_json_doc "ai_outsourcing_disclosed" "${ROOT_DIR}/.well-known/governance-layer-manifest.json" \
    ".well-known/governance-layer-manifest.json" "Create GLM manifest documenting AI provider outsourcing"

  # Check 3: autonomous mode safety gates
  check_doc "autonomous_safety_gates" "${ROOT_DIR}/docs/rules/domain/autonomous-safety.md" \
    'agent/|PR Draft|merge' "autonomous change management gates" \
    "Document DORA-compliant ICT change management gates in autonomous-safety.md"
}

# ── Run frameworks ────────────────────────────────────────────────────────────

ASSESSED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

run_framework() {
  local fw="$1"
  CHECKS_JSON=""
  TOTAL=0
  PASSED=0

  case "$fw" in
    eu-ai-act) check_eu_ai_act ;;
    gdpr)      check_gdpr ;;
    nis2)      check_nis2 ;;
    dora)      check_dora ;;
    *) die "unknown framework: ${fw}. Valid: eu-ai-act, gdpr, nis2, dora" ;;
  esac

  local score=0
  [[ "$TOTAL" -gt 0 ]] && score=$(( PASSED * 100 / TOTAL ))

  cat <<JSON
{
  "framework": "${fw}",
  "tenant": "${TENANT_LABEL}",
  "assessed_at": "${ASSESSED_AT}",
  "score": ${score},
  "passed": ${PASSED},
  "total": ${TOTAL},
  "checks": [${CHECKS_JSON}
  ]
}
JSON
}

output_json() {
  local content="$1"
  if [[ -n "$OUTPUT_FILE" ]]; then
    printf '%s\n' "$content" > "$OUTPUT_FILE" 2>/dev/null \
      || die "cannot write output file: ${OUTPUT_FILE}"
    echo "Written to ${OUTPUT_FILE}" >&2
  else
    printf '%s\n' "$content"
  fi
}

# Exit 0 solo si todos los marcos evaluados puntúan 100.
ALL_FAIL=0
if [[ "$FRAMEWORK" == "all" ]]; then
  frameworks=("eu-ai-act" "gdpr" "nis2" "dora")
else
  frameworks=("$FRAMEWORK")
fi

parts=()
for fw in "${frameworks[@]}"; do
  result="$(run_framework "$fw")"
  parts+=("$result")
  grep -q '"score": 100,' <<<"$result" || ALL_FAIL=1
done

if [[ "$FRAMEWORK" == "all" ]]; then
  content="["
  for i in "${!parts[@]}"; do
    [[ "$i" -gt 0 ]] && content+=","
    content+=$'\n'"${parts[$i]}"
  done
  content+=$'\n'"]"
else
  content="${parts[0]}"
fi

output_json "$content"
exit $ALL_FAIL
