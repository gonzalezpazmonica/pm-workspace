#!/bin/bash
# lib/profile-gate.sh — Savia Hook Profile Gate
# Source this at the top of any hook to conditionally skip based on SAVIA_HOOK_PROFILE.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/profile-gate.sh"
#   profile_gate "standard"   # exits 0 (skip) if profile is below this tier
#
# Profiles (ascending strictness):
#   minimal  — only hard security blockers (credential leak, force push, data sovereignty)
#   standard — minimal + all quality/workflow gates (default)
#   strict   — standard + extra scrutiny (agent dispatch, competence tracking, extra QA)
#   ci       — same gates as standard, but non-interactive (no prompts, exit codes only)
#
# Tier hierarchy: security < standard < strict
# CI mode is orthogonal — it changes interactivity, not gate selection.

SAVIA_HOOK_PROFILE="${SAVIA_HOOK_PROFILE:-standard}"

# profile_gate REQUIRED_TIER
# If the current profile doesn't include this tier, exits 0 (hook is skipped silently).
# Tier values: security | standard | strict
profile_gate() {
  local required="${1:-standard}"

  case "$SAVIA_HOOK_PROFILE" in
    minimal)
      [[ "$required" == "security" ]] && return 0
      exit 0   # skip: non-security hook in minimal mode
      ;;
    standard|ci)
      [[ "$required" == "security" || "$required" == "standard" ]] && return 0
      exit 0   # skip: strict-only hook
      ;;
    strict)
      return 0 # all tiers run
      ;;
    *)
      return 0 # unknown profile → standard behavior (safe default)
      ;;
  esac
}

# is_interactive — returns true unless in ci mode
# Use to guard prompts/confirmations: is_interactive && read -r answer || answer="y"
is_interactive() {
  [[ "$SAVIA_HOOK_PROFILE" != "ci" ]]
}

# profile_skip_msg HOOK_NAME — prints a debug message when skipped (only if SAVIA_HOOK_DEBUG=1)
profile_skip_msg() {
  [[ "${SAVIA_HOOK_DEBUG:-0}" == "1" ]] && \
    echo "hook-profile: skipped ${1:-hook} (profile=$SAVIA_HOOK_PROFILE)" >&2
  true
}
