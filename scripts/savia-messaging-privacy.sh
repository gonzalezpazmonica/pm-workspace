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
  grep -qEi '[0-9]+[.,]?[0-9]*\s*(EUR|USD|GBP|€|\$|£|mill|M€|M\$)' <<< "$subject" \
    && warnings+=("monetary amount")
  grep -qEi '(EUR|USD|GBP|€|\$|£)\s*[0-9]' <<< "$subject" \
    && warnings+=("monetary amount")

  # Dates that suggest deadlines / contract terms
  grep -qEi '[0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}' <<< "$subject" \
    && warnings+=("specific date")

  # Names (common patterns: company names with Ltd/SL/SA)
  grep -qEi '\b(S\.?L\.?|S\.?A\.?|Ltd|GmbH|Inc|Corp)\b' <<< "$subject" \
    && warnings+=("company name")

  # Secrets / credentials patterns (reuse privacy-check patterns)
  grep -qEi 'AKIA[0-9A-Z]{16}' <<< "$subject" && warnings+=("AWS key")
  grep -qEi 'ghp_[a-zA-Z0-9]{36}' <<< "$subject" && warnings+=("GitHub PAT")
  grep -qEi 'sk-[a-zA-Z0-9]{20,}' <<< "$subject" && warnings+=("API key")
  grep -qEi '(password|contraseña|clave|passwd|secret)' <<< "$subject" \
    && warnings+=("credential keyword")

  # IPs / connection strings
  grep -qE '(10\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.)' <<< "$subject" \
    && warnings+=("private IP")
  grep -qEi '(jdbc:|mongodb|Server=.*Password)' <<< "$subject" \
    && warnings+=("connection string")

  # Emails / phones
  grep -qEi '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-z]{2,}' <<< "$subject" \
    && warnings+=("email address")
  grep -qE '\+?[0-9]{2,4}[\s.-]?[0-9]{6,}' <<< "$subject" \
    && warnings+=("phone number")

  # DNI/NIF/NIE (Spanish ID)
  grep -qEi '\b[0-9]{8}[A-Z]\b|\b[XYZ][0-9]{7}[A-Z]\b' <<< "$subject" \
    && warnings+=("ID number (DNI/NIE)")

  # IBAN
  grep -qEi '\b[A-Z]{2}[0-9]{2}\s?[0-9A-Z]{4}\s?[0-9]{4}' <<< "$subject" \
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
