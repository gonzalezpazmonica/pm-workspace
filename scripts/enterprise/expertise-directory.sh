#!/usr/bin/env bash
# expertise-directory.sh — SE-023 Knowledge Federation
# Builds an expertise directory from user profiles (N4 compliant).
#
# Usage:
#   scripts/enterprise/expertise-directory.sh [--output-dir DIR]
#
# N4 compliance: only shows data explicitly declared by each user.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

PROFILES_DIR="${REPO_ROOT}/.claude/profiles/users"
OUTPUT_DIR="${REPO_ROOT}/output/enterprise"

# ── arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: expertise-directory.sh [--output-dir DIR]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="${OUTPUT_DIR}/expertise-directory.json"

# Returns frontmatter value for a given key from a file
_fm_value() {
  local file="$1"
  local key="$2"
  grep -m1 "^${key}:" "$file" 2>/dev/null | sed "s/^${key}:[[:space:]]*//" | tr -d '"' || true
}

# ── build JSON ────────────────────────────────────────────────────────────────
_build_json() {
  printf '{\n'
  printf '  "generated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "users": [\n'

  local first_user=true

  if [[ -d "$PROFILES_DIR" ]]; then
    for identity_file in "${PROFILES_DIR}"/*/identity.md; do
      [[ -f "$identity_file" ]] || continue

      local slug
      slug="$(basename "$(dirname "$identity_file")")"
      [[ "$slug" == "template" ]] && continue

      local uname urole
      uname="$(_fm_value "$identity_file" "name")"
      urole="$(_fm_value "$identity_file" "role")"

      local tools_file
      tools_file="$(dirname "$identity_file")/tools.md"
      local skills_json="[]"
      if [[ -f "$tools_file" ]]; then
        local skills_raw
        mapfile -t skills_raw < <(grep -E '^\s*[-*]' "$tools_file" 2>/dev/null \
          | sed 's/^\s*[-*]\s*//' | head -20 || true)
        if [[ ${#skills_raw[@]} -gt 0 ]]; then
          skills_json="["
          local first_skill=true
          for skill in "${skills_raw[@]}"; do
            [[ -z "$skill" ]] && continue
            skill="$(printf '%s' "$skill" | tr -d '"' | head -c 60)"
            if [[ "$first_skill" == "true" ]]; then
              first_skill=false
            else
              skills_json+=","
            fi
            skills_json+="\"${skill}\""
          done
          skills_json+="]"
        fi
      fi

      local projects_file
      projects_file="$(dirname "$identity_file")/projects.md"
      local pcount=0
      if [[ -f "$projects_file" ]]; then
        pcount="$(grep -cE '^\s*[-*]' "$projects_file" 2>/dev/null || true)"
        pcount="${pcount:-0}"
      fi

      local last_active
      last_active="$(_fm_value "$identity_file" "updated")"
      [[ -z "$last_active" ]] && last_active="unknown"

      local display_name="${uname:-$slug}"

      if [[ "$first_user" == "true" ]]; then
        first_user=false
      else
        printf ',\n'
      fi

      printf '    {\n'
      printf '      "slug": "%s",\n' "$slug"
      printf '      "display_name": "%s",\n' "$display_name"
      printf '      "role": "%s",\n' "${urole:-unknown}"
      printf '      "skills": %s,\n' "$skills_json"
      printf '      "projects_count": %d,\n' "$pcount"
      printf '      "last_active": "%s"\n' "$last_active"
      printf '    }'
    done
  fi

  printf '\n  ]\n'
  printf '}\n'
}

_build_json > "$OUTPUT_FILE"
echo "expertise-directory written: $OUTPUT_FILE"
