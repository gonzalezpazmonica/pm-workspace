#!/bin/bash
# privacy-check-company.sh — Privacy filter for company repo content
# Uso: bash scripts/privacy-check-company.sh <repo_dir> [handle]
#
# Scans company repo content before push for secrets and private data.
# Reuses validate_privacy() patterns from contribute.sh.

set -euo pipefail

# ── Constantes ──────────────────────────────────────────────────────
WORKSPACE_DIR="${PM_WORKSPACE_ROOT:-$HOME/claude}"

# ── Colores ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${BLUE}ℹ${NC}  $1"; }
log_ok()    { echo -e "${GREEN}✅${NC} $1"; }
log_warn()  { echo -e "${YELLOW}⚠️${NC}  $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

# ── Privacy validation (reuse patterns from contribute.sh) ─────────
check_content() {
  local content="$1"
  local violations=()

  # PATs and tokens
  echo "$content" | grep -qEi 'AKIA[0-9A-Z]{16}' && violations+=("AWS Access Key")
  echo "$content" | grep -qEi 'ghp_[a-zA-Z0-9]{36}' && violations+=("GitHub PAT")
  echo "$content" | grep -qEi 'sk-[a-zA-Z0-9]{20,}' && violations+=("API key (sk-)")
  echo "$content" | grep -qE 'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}' && violations+=("JWT token")

  # Private IPs
  echo "$content" | grep -qE '(10\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+)' \
    && violations+=("Private IP address")

  # Connection strings
  echo "$content" | grep -qEi '(Server=.*Password=|jdbc:|mongodb\+srv://)' \
    && violations+=("Connection string")

  # Private keys (actual key content, not pubkey references)
  echo "$content" | grep -qE '-----BEGIN (RSA |EC )?PRIVATE KEY-----' \
    && violations+=("Private key content")

  printf '%s\n' "${violations[@]+"${violations[@]}"}"
}

# ── Scan staged files in company repo ──────────────────────────────
do_scan() {
  local repo_dir="${1:?Uso: privacy-check-company.sh <repo_dir> [handle]}"
  local handle="${2:-}"
  local all_violations=()

  if [ ! -d "$repo_dir/.git" ]; then
    log_error "Not a git repo: $repo_dir"
    return 1
  fi

  log_info "Scanning company repo for private data..."

  # Scan staged changes
  local staged_diff
  staged_diff=$(git -C "$repo_dir" diff --cached 2>/dev/null || true)

  if [ -n "$staged_diff" ]; then
    local added_lines
    added_lines=$(echo "$staged_diff" | grep '^+' | grep -v '^\+\+\+' || true)
    if [ -n "$added_lines" ]; then
      local violations
      violations=$(check_content "$added_lines")
      if [ -n "$violations" ]; then
        while IFS= read -r v; do
          [ -n "$v" ] && all_violations+=("Staged: $v")
        done <<< "$violations"
      fi
    fi
  fi

  # Scan personal inbox messages (unread) for handle
  if [ -n "$handle" ] && [ -d "$repo_dir/users/$handle/inbox/unread" ]; then
    for msg_file in "$repo_dir/users/$handle/inbox/unread"/*.md; do
      [ -f "$msg_file" ] || continue
      local msg_content
      msg_content=$(cat "$msg_file")
      local violations
      violations=$(check_content "$msg_content")
      if [ -n "$violations" ]; then
        while IFS= read -r v; do
          [ -n "$v" ] && all_violations+=("Message $(basename "$msg_file"): $v")
        done <<< "$violations"
      fi
    done
  fi

  # Scan personal documents folder
  if [ -n "$handle" ] && [ -d "$repo_dir/users/$handle/documents" ]; then
    for doc_file in "$repo_dir/users/$handle/documents"/*; do
      [ -f "$doc_file" ] || continue
      local doc_content
      doc_content=$(cat "$doc_file")
      local violations
      violations=$(check_content "$doc_content")
      if [ -n "$violations" ]; then
        while IFS= read -r v; do
          [ -n "$v" ] && all_violations+=("Document $(basename "$doc_file"): $v")
        done <<< "$violations"
      fi
    done
  fi

  # Report
  if [ ${#all_violations[@]} -gt 0 ]; then
    log_error "Privacy check FAILED — ${#all_violations[@]} violation(s):"
    for v in "${all_violations[@]}"; do
      echo -e "  ${RED}•${NC} $v"
    done
    return 1
  fi

  log_ok "Privacy check PASSED — no violations found"
  return 0
}

# ── Main ────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-help}"

  case "$cmd" in
    help|--help|-h)
      echo "privacy-check-company.sh — Privacy filter for company repo"
      echo ""
      echo "Uso: bash scripts/privacy-check-company.sh <repo_dir> [handle]"
      echo ""
      echo "Scans staged changes and personal folders for secrets/private data."
      echo "Returns exit code 0 (PASS) or 1 (FAIL)."
      ;;
    *)
      do_scan "$@" ;;
  esac
}

main "$@"
