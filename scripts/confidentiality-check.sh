#!/usr/bin/env bash
# confidentiality-check.sh — Verify project files comply with confidentiality levels
# Usage: confidentiality-check.sh <project-dir> [--report <output-path>]
set -uo pipefail

PROJECT_DIR="${1:-.}"
REPORT_PATH=""
if [[ "${2:-}" == "--report" ]]; then REPORT_PATH="${3:-}"; fi

CRITICAL=0
WARNING=0
INFO=0
FINDINGS=""

add_finding() {
  local sev="$1" file="$2" msg="$3"
  FINDINGS+="$sev | $file | $msg\n"
  case "$sev" in
    CRITICAL) CRITICAL=$((CRITICAL+1)) ;;
    WARNING)  WARNING=$((WARNING+1)) ;;
    INFO)     INFO=$((INFO+1)) ;;
  esac
}

# ── Check: PII in N4-SHARED (should not have personal data) ──────────────────
scan_pii() {
  local file="$1"
  local content
  content=$(cat "$file" 2>/dev/null || true)
  # Salary, compensation
  if echo "$content" | grep -qiE '(salario|sueldo|retribucion|compensacion|nivelacion salarial|40K|35K|45K)'; then
    add_finding "CRITICAL" "$file" "Salary/compensation data in shared repo"
  fi
  # Personal threats, burnout, emotional state
  if echo "$content" | grep -qiE '(amenaza.*salida|quiere irse|no esta a gusto|burnout|desmotivado|frustra)'; then
    add_finding "WARNING" "$file" "Personal emotional/exit risk data (should be in N4-VASS or N4b-PM)"
  fi
  # One-to-one references
  if echo "$content" | grep -qiE '(one.to.one|one2one|1:1.*transcripcion|sesion privada)'; then
    add_finding "WARNING" "$file" "Reference to private 1:1 content (should be in N4b-PM)"
  fi
  # DNI, IBAN, phone
  if echo "$content" | grep -qE '[0-9]{8}[A-Z]|ES[0-9]{22}|\+34[0-9]{9}'; then
    add_finding "CRITICAL" "$file" "Spanish PII pattern (DNI/IBAN/phone)"
  fi
}

# ── Check: Secrets ────────────────────────────────────────────────────────────
scan_secrets() {
  local file="$1"
  local content
  content=$(cat "$file" 2>/dev/null || true)
  if echo "$content" | grep -qE '(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|-----BEGIN.*PRIVATE KEY)'; then
    add_finding "CRITICAL" "$file" "Credential/secret detected"
  fi
  if echo "$content" | grep -qiE 'password\s*[=:]\s*[^$\{"\x27]{4,}'; then
    add_finding "CRITICAL" "$file" "Hardcoded password"
  fi
}

# ── Check: Cross-level references ─────────────────────────────────────────────
scan_cross_refs() {
  local file="$1"
  local content
  content=$(cat "$file" 2>/dev/null || true)
  # N4-SHARED file referencing N4b-PM content directly (not just pointer)
  if echo "$content" | grep -qiE '(evaluacion de competencias|feedback personal|ficha individual)'; then
    add_finding "WARNING" "$file" "N4b-PM content leaked into shared file"
  fi
}

# ── Check: CONFIDENTIALITY.md exists ──────────────────────────────────────────
if [[ ! -f "$PROJECT_DIR/CONFIDENTIALITY.md" ]]; then
  add_finding "INFO" "CONFIDENTIALITY.md" "No CONFIDENTIALITY.md found — recommended for multi-repo projects"
fi

# ── Scan all .md files ────────────────────────────────────────────────────────
echo "Scanning $PROJECT_DIR ..."
FILE_COUNT=0
while IFS= read -r -d '' file; do
  FILE_COUNT=$((FILE_COUNT+1))
  rel="${file#$PROJECT_DIR/}"
  # Skip meta-files, agent-memory and output dirs
  [[ "$rel" == agent-memory/* || "$rel" == output/* || "$rel" == CONFIDENTIALITY.md ]] && continue
  scan_pii "$file"
  scan_secrets "$file"
  scan_cross_refs "$file"
done < <(find "$PROJECT_DIR" -name "*.md" -not -path "*/.git/*" -print0 2>/dev/null)

# ── Score ─────────────────────────────────────────────────────────────────────
SCORE=$((100 - CRITICAL*25 - WARNING*5 - INFO*1))
[[ $SCORE -lt 0 ]] && SCORE=0

# ── Output ────────────────────────────────────────────────────────────────────
echo ""
echo "Files scanned: $FILE_COUNT"
echo "Score: $SCORE/100"
echo "  CRITICAL: $CRITICAL"
echo "  WARNING: $WARNING"
echo "  INFO: $INFO"

if [[ $((CRITICAL + WARNING + INFO)) -gt 0 ]]; then
  echo ""
  echo "Findings:"
  printf "%b" "$FINDINGS" | while IFS='|' read -r sev file msg; do
    echo "  $sev —$file —$msg"
  done
fi

# ── Report file ───────────────────────────────────────────────────────────────
if [[ -n "$REPORT_PATH" ]]; then
  mkdir -p "$(dirname "$REPORT_PATH")"
  {
    echo "# Confidentiality Check — $(basename "$PROJECT_DIR")"
    echo ""
    echo "- Date: $(date +%Y-%m-%d)"
    echo "- Score: $SCORE/100"
    echo "- Files scanned: $FILE_COUNT"
    echo "- CRITICAL: $CRITICAL | WARNING: $WARNING | INFO: $INFO"
    echo ""
    if [[ $((CRITICAL + WARNING + INFO)) -gt 0 ]]; then
      echo "## Findings"
      echo ""
      printf "%b" "$FINDINGS" | while IFS='|' read -r sev file msg; do
        echo "- **$sev** —$file —$msg"
      done
    else
      echo "No violations found."
    fi
  } > "$REPORT_PATH"
  echo ""
  echo "Report: $REPORT_PATH"
fi

# Exit code: 1 if critical, 0 otherwise
[[ $CRITICAL -gt 0 ]] && exit 1
exit 0
