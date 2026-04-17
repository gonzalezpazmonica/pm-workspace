#!/bin/bash
set -uo pipefail
# hook-profile.sh — Get/set the active SAVIA_HOOK_PROFILE
# Usage: hook-profile.sh get | set <profile>

PROFILE_FILE="${HOME}/.savia/hook-profile"
VALID_PROFILES="minimal standard strict ci"

usage() {
  cat <<EOF
hook-profile.sh — Savia Hook Profile Manager

Usage:
  hook-profile.sh get               Show active profile
  hook-profile.sh set <profile>     Set profile (persists to ~/.savia/hook-profile)
  hook-profile.sh list              List all profiles with descriptions

Profiles:
  minimal   Only hard security blockers (no quality gates)
  standard  Security + all quality/workflow gates (default)
  strict    Standard + extra scrutiny for critical code
  ci        Same as standard but non-interactive (for CI/CD pipelines)

The active profile is read from:
  1. \$SAVIA_HOOK_PROFILE env var (highest priority)
  2. ~/.savia/hook-profile file
  3. "standard" (default)
EOF
}

get_profile() {
  if [[ -n "${SAVIA_HOOK_PROFILE:-}" ]]; then
    echo "$SAVIA_HOOK_PROFILE (env var)"
  elif [[ -f "$PROFILE_FILE" ]]; then
    local p
    p=$(cat "$PROFILE_FILE")
    echo "$p (from ~/.savia/hook-profile)"
  else
    echo "standard (default)"
  fi
}

set_profile() {
  local profile="${1:-}"
  if [[ -z "$profile" ]]; then
    echo "Error: profile name required" >&2
    echo "Valid profiles: $VALID_PROFILES" >&2
    exit 1
  fi

  if ! echo "$VALID_PROFILES" | grep -qw "$profile"; then
    echo "Error: unknown profile '$profile'" >&2
    echo "Valid profiles: $VALID_PROFILES" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$PROFILE_FILE")"
  echo "$profile" > "$PROFILE_FILE"
  echo "Hook profile set to: $profile"
  echo "Persisted to: $PROFILE_FILE"
  echo ""
  echo "To apply in current shell: export SAVIA_HOOK_PROFILE=$profile"
}

list_profiles() {
  cat <<EOF
Available hook profiles:

  minimal   Only hard security blockers (credential leak, force push, data sovereignty)
            Use for: demos, onboarding, debugging hooks

  standard  Security + all quality/workflow gates          [DEFAULT]
            Use for: daily development

  strict    Standard + extra scrutiny (agent dispatch, competence tracking)
            Use for: pre-release, critical code, security-sensitive changes

  ci        Same gates as standard but non-interactive (no prompts, exit-code only)
            Use for: CI/CD pipelines, GitHub Actions, Azure Pipelines

Current: $(get_profile)
EOF
}

case "${1:-}" in
  get)    get_profile ;;
  set)    set_profile "${2:-}" ;;
  list)   list_profiles ;;
  help|-h|--help) usage ;;
  "")     get_profile ;;
  *)
    echo "Unknown command: $1" >&2
    usage >&2
    exit 1
    ;;
esac
