#!/usr/bin/env bash
# pm-backend-health.sh — SE-092 MVP: detect PM backend configuration
set -uo pipefail
#
# Outputs JSON with backend detection results.
# Exit code: always 0 (no secrets exposed, safe to run anywhere).
#
# Output fields:
#   backend    : "ado" | "jira" | "none"
#   configured : true | false  (required env vars/config present)
#   pat_file_exists : true | false
#   project    : project name or ""
#   org_url    : org URL or ""  (masked if sensitive)
#   notes      : human-readable status
#
# Rules:
#   - NEVER read PAT content — only check file existence
#   - NEVER output PAT value — only report file presence
#   - NEVER fail with exit 1 — always exit 0
#
# Ref: SE-092, docs/propuestas/SE-092-PM-BACKEND.md, Rule #1 (no hardcoded PAT)

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# ── Read config (no secrets) ─────────────────────────────────────────────────

# Default PAT file locations (checked for existence only — NEVER read content)
PAT_FILE_DEFAULT="$HOME/.azure/devops-pat"
PAT_FILE_ALT="${AZURE_DEVOPS_PAT_FILE:-}"

# Detect backend type
backend="none"
configured=false
pat_file_exists=false
project=""
org_url=""
notes=""

# ── Check Azure DevOps ───────────────────────────────────────────────────────

ado_signals=0

# Signal 1: AZURE_DEVOPS_ORG_URL env var
if [[ -n "${AZURE_DEVOPS_ORG_URL:-}" ]]; then
  ado_signals=$((ado_signals + 1))
  # Mask to org name only (no full URL in output for safety)
  org_url="$(echo "${AZURE_DEVOPS_ORG_URL}" | sed 's|https://dev.azure.com/||' | cut -d'/' -f1)"
fi

# Signal 2: AZURE_DEVOPS_PROJECT env var
if [[ -n "${AZURE_DEVOPS_PROJECT:-}" ]]; then
  ado_signals=$((ado_signals + 1))
  project="${AZURE_DEVOPS_PROJECT}"
fi

# Signal 3: pm-config.local.md contains project config
local_config="$REPO_ROOT/.claude/rules/pm-config.local.md"
if [[ -f "$local_config" ]]; then
  if grep -q 'PROJECT_.*_NAME' "$local_config" 2>/dev/null; then
    ado_signals=$((ado_signals + 1))
    if [[ -z "$project" ]]; then
      # Extract first project name as hint (no sensitive data)
      project=$(grep -m1 'PROJECT_.*_NAME\s*=' "$local_config" 2>/dev/null \
        | sed 's/.*=\s*"\(.*\)".*/\1/' | head -1 || echo "")
    fi
  fi
fi

# Signal 4: PAT file exists (NEVER read content)
if [[ -f "$PAT_FILE_DEFAULT" ]]; then
  pat_file_exists=true
  ado_signals=$((ado_signals + 1))
elif [[ -n "$PAT_FILE_ALT" ]] && [[ -f "$PAT_FILE_ALT" ]]; then
  pat_file_exists=true
  ado_signals=$((ado_signals + 1))
elif [[ -n "${AZURE_DEVOPS_EXT_PAT:-}" ]] || [[ -n "${AZURE_PAT:-}" ]]; then
  # Env var PAT exists (only check non-empty, never output value)
  pat_file_exists=true
  ado_signals=$((ado_signals + 1))
fi

if [[ "$ado_signals" -ge 2 ]]; then
  backend="ado"
  if [[ "$ado_signals" -ge 3 ]] && [[ "$pat_file_exists" == "true" ]]; then
    configured=true
    notes="Azure DevOps configured. PAT file present. Ready for queries."
  elif [[ "$ado_signals" -ge 2 ]]; then
    configured=false
    notes="Azure DevOps partially configured. Missing: $(
      [[ "$pat_file_exists" == "false" ]] && echo "PAT file ($PAT_FILE_DEFAULT). "
      [[ -z "$project" ]] && echo "AZURE_DEVOPS_PROJECT env var."
    )"
  fi
fi

# ── Check Jira ───────────────────────────────────────────────────────────────

if [[ "$backend" == "none" ]]; then
  jira_signals=0
  if [[ -n "${JIRA_BASE_URL:-}" ]]; then
    jira_signals=$((jira_signals + 1))
    org_url="$(echo "${JIRA_BASE_URL}" | sed 's|https://||' | cut -d'/' -f1)"
  fi
  if [[ -n "${JIRA_PROJECT_KEY:-}" ]]; then
    jira_signals=$((jira_signals + 1))
    project="${JIRA_PROJECT_KEY}"
  fi
  if [[ -n "${JIRA_API_TOKEN:-}" ]] || [[ -f "$HOME/.jira/token" ]]; then
    jira_signals=$((jira_signals + 1))
    pat_file_exists=true
  fi
  if [[ "$jira_signals" -ge 2 ]]; then
    backend="jira"
    if [[ "$jira_signals" -ge 3 ]]; then
      configured=true
      notes="Jira configured. Token present. Ready for queries."
    else
      configured=false
      notes="Jira partially configured. Missing: token or project key."
    fi
  fi
fi

# ── None detected ────────────────────────────────────────────────────────────

if [[ "$backend" == "none" ]]; then
  notes="No PM backend configured. Set AZURE_DEVOPS_ORG_URL + AZURE_DEVOPS_PROJECT + PAT file at $PAT_FILE_DEFAULT, or Jira equivalents."
fi

# ── JSON output (always exit 0) ───────────────────────────────────────────────

python3 -c "
import json, sys
data = {
  'backend':         '${backend}',
  'configured':      '${configured}' == 'true',
  'pat_file_exists': '${pat_file_exists}' == 'true',
  'project':         '${project}',
  'org':             '${org_url}',
  'notes':           '${notes}'
}
print(json.dumps(data, indent=2))
" 

exit 0
