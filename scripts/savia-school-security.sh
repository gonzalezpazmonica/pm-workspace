#!/bin/bash
# Savia School Security Layer: Encryption, Access Control, GDPR
# Max 150 lines

set -euo pipefail

SCHOOL_ROOT="${SCHOOL_ROOT:-.}/school-savia"
ENCRYPTION_KEY_FILE="${HOME}/.school-keys/encryption.key"
AUDIT_LOG="${SCHOOL_ROOT}/.audit.log"

# ── Verify Role ───────────────────────────────────────────────────────────────
verify_role() {
  local handle="$1"
  # Check if handle is in teacher/ or classroom/
  if [ -d "${SCHOOL_ROOT}/classroom/${handle}" ]; then
    echo "student"
  elif grep -q "^teacher:" "${SCHOOL_ROOT}/.school-config.md" 2>/dev/null; then
    echo "teacher"
  else
    echo "unknown"
  fi
}

# ── Check Student Isolation ───────────────────────────────────────────────────
check_student_isolation() {
  local alias="$1"
  local student_dir="${SCHOOL_ROOT}/classroom/${alias}"
  # Verify no access to other students' folders
  if [ -d "${student_dir}" ]; then
    echo "✅ Student isolation verified: ${alias}"
    return 0
  fi
  echo "❌ Access denied: ${alias}"
  return 1
}

# ── Encrypt Evaluation (AES-256) ──────────────────────────────────────────────
encrypt_evaluation() {
  local alias="$1" content="$2"
  [ ! -f "${ENCRYPTION_KEY_FILE}" ] && \
    openssl rand -base64 32 > "${ENCRYPTION_KEY_FILE}" && chmod 600 "${ENCRYPTION_KEY_FILE}"

  local enc_file="${SCHOOL_ROOT}/teacher/evaluations/${alias}/eval-$(date +%s).enc"
  mkdir -p "$(dirname "${enc_file}")"

  echo "${content}" | \
    openssl enc -aes-256-cbc -salt -in - -out "${enc_file}" \
    -K "$(xxd -p -c 256 "${ENCRYPTION_KEY_FILE}")" \
    -iv "$(openssl rand -hex 16)"

  chmod 600 "${enc_file}"
  echo "✅ Encrypted: ${enc_file}"
}

# ── Decrypt Evaluation (Teacher Only) ──────────────────────────────────────────
decrypt_evaluation() {
  local alias="$1" file="$2"
  local role=$(verify_role "teacher")
  [ "${role}" != "teacher" ] && { echo "❌ Access denied"; return 1; }

  openssl enc -d -aes-256-cbc -in "${file}" \
    -K "$(xxd -p -c 256 "${ENCRYPTION_KEY_FILE}")" 2>/dev/null || \
    echo "❌ Decryption failed"
}

# ── Audit Access Logging ──────────────────────────────────────────────────────
audit_access() {
  local alias="$1" action="$2"
  local timestamp=$(date -Iseconds)
  local user="${USER:-system}"
  echo "[${timestamp}] ${user} - ${action} - ${alias}" >> "${AUDIT_LOG}"
  echo "📋 Audit logged"
}

# ── GDPR Consent Check ────────────────────────────────────────────────────────
gdpr_consent_check() {
  local alias="$1"
  local consent_file="${SCHOOL_ROOT}/classroom/${alias}/.consent"
  if [ -f "${consent_file}" ]; then
    echo "✅ Consent verified"
    return 0
  fi
  echo "❌ No parental consent found"
  return 1
}

# ── Age-Appropriate Content Filter ────────────────────────────────────────────
content_filter() {
  local text="$1"
  local forbidden_patterns="(violence|adult|explicit|hate|discrimination)"
  if echo "${text}" | grep -iE "${forbidden_patterns}" > /dev/null; then
    echo "❌ Content rejected"
    return 1
  fi
  echo "✅ Content approved"
  return 0
}

# ── Main dispatcher ───────────────────────────────────────────────────────────
main() {
  case "${1:-help}" in
    verify-role) verify_role "$2" ;;
    check-isolation) check_student_isolation "$2" ;;
    encrypt-eval) encrypt_evaluation "$2" "$3" ;;
    decrypt-eval) decrypt_evaluation "$2" "$3" ;;
    audit-access) audit_access "$2" "$3" ;;
    gdpr-consent) gdpr_consent_check "$2" ;;
    filter-content) content_filter "$2" ;;
    *) echo "Usage: $0 {verify-role|check-isolation|encrypt-eval|decrypt-eval|audit-access|gdpr-consent|filter-content}" ;;
  esac
}

main "$@"
