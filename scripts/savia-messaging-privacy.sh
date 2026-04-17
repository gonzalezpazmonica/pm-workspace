#!/bin/bash
# savia-messaging-privacy.sh — Subject sensitivity check
# Sourced by savia-messaging.sh — do NOT run directly.
#
# Subjects are NEVER encrypted (needed for inbox routing/display).
# This module warns when the subject contains data that should go
# in the encrypted body instead.
# Guides both human users and AI agents toward safe subject lines.

# ── Subject sensitivity check ─────────────────────────────────────
check_subject_sensitivity() {
  local subject="$1" encrypt="$2"
  local warnings=()

  # Money / amounts (€, $, USD, EUR + number combos)
  echo "$subject" | grep -qEi '[0-9]+[.,]?[0-9]*\s*(EUR|USD|GBP|€|\$|£|mill|M€|M\$)' \
    && warnings+=("monetary amount")
  echo "$subject" | grep -qEi '(EUR|USD|GBP|€|\$|£)\s*[0-9]' \
    && warnings+=("monetary amount")

  # Dates that suggest deadlines / contract terms
  echo "$subject" | grep -qEi '[0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}' \
    && warnings+=("specific date")

  # Names (common patterns: company names with Ltd/SL/SA)
  echo "$subject" | grep -qEi '\b(S\.?L\.?|S\.?A\.?|Ltd|GmbH|Inc|Corp)\b' \
    && warnings+=("company name")

  # Secrets / credentials patterns (reuse privacy-check patterns)
  echo "$subject" | grep -qEi 'AKIA[0-9A-Z]{16}' && warnings+=("AWS key")
  echo "$subject" | grep -qEi 'ghp_[a-zA-Z0-9]{36}' && warnings+=("GitHub PAT")
  echo "$subject" | grep -qEi 'sk-[a-zA-Z0-9]{20,}' && warnings+=("API key")
  echo "$subject" | grep -qEi '(password|contraseña|clave|passwd|secret)' \
    && warnings+=("credential keyword")

  # IPs / connection strings
  echo "$subject" | grep -qE '(10\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.)' \
    && warnings+=("private IP")
  echo "$subject" | grep -qEi '(jdbc:|mongodb|Server=.*Password)' \
    && warnings+=("connection string")

  # Emails / phones
  echo "$subject" | grep -qEi '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-z]{2,}' \
    && warnings+=("email address")
  echo "$subject" | grep -qE '\+?[0-9]{2,4}[\s.-]?[0-9]{6,}' \
    && warnings+=("phone number")

  # DNI/NIF/NIE (Spanish ID)
  echo "$subject" | grep -qEi '\b[0-9]{8}[A-Z]\b|\b[XYZ][0-9]{7}[A-Z]\b' \
    && warnings+=("ID number (DNI/NIE)")

  # IBAN
  echo "$subject" | grep -qEi '\b[A-Z]{2}[0-9]{2}\s?[0-9A-Z]{4}\s?[0-9]{4}' \
    && warnings+=("IBAN")

  if [ ${#warnings[@]} -gt 0 ]; then
    local joined
    joined=$(printf '%s, ' "${warnings[@]}")
    joined="${joined%, }"
    log_warn "Subject contains sensitive data: ${joined}"
    log_warn "Subjects are NEVER encrypted — they stay in cleartext for inbox display."
    log_warn "Move sensitive details to the message body and use --encrypt."
    if [ "$encrypt" = "true" ]; then
      log_info "Tip: Use a generic subject like 'Confidential' or 'Encrypted message'."
    fi
    return 1
  fi
  return 0
}
