#!/usr/bin/env bash
# detect-frontend.sh — SPEC-INSTALLER-OPENCODE-MIGRATION
#
# Detecta que frontends AI estan disponibles en el sistema.
# Usado por install.sh y documentacion de setup.
#
# Output JSON:
#   {
#     "opencode": bool,
#     "claude_code": bool,
#     "codex": bool,
#     "cursor": bool,
#     "recommended": "opencode" | "claude_code" | "codex" | "none",
#     "version": {
#       "opencode": "v1.14.0" | null,
#       "claude_code": "1.2.3"  | null,
#       "codex": "0.1.0"        | null
#     }
#   }
#
# Exit codes:
#   0 — at least one frontend detected
#   1 — no frontend detected
#
# Ref: docs/propuestas/SPEC-INSTALLER-OPENCODE-MIGRATION.md
# Ref: docs/setup/frontend-migration-guide.md

set -euo pipefail

# ── Detect version of a command ───────────────────────────────────────────────
get_version() {
  local cmd="$1"
  local version_flag="${2:---version}"
  command -v "$cmd" &>/dev/null || { echo "null"; return; }
  local v
  v=$("$cmd" "$version_flag" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)
  if [[ -n "$v" ]]; then
    echo "\"$v\""
  else
    echo "\"found\""
  fi
}

# ── Detect frontends ──────────────────────────────────────────────────────────
OPENCODE=false
CLAUDE_CODE=false
CODEX=false
CURSOR=false

OC_VERSION="null"
CC_VERSION="null"
CODEX_VERSION="null"

if command -v opencode &>/dev/null; then
  OPENCODE=true
  OC_VERSION=$(get_version opencode --version)
fi

if command -v claude &>/dev/null; then
  CLAUDE_CODE=true
  CC_VERSION=$(get_version claude --version)
fi

# codex CLI (OpenAI)
if command -v codex &>/dev/null; then
  CODEX=true
  CODEX_VERSION=$(get_version codex --version)
fi

# cursor (check common install paths)
if command -v cursor &>/dev/null || [[ -f "$HOME/.local/bin/cursor" ]] || [[ -f "/usr/local/bin/cursor" ]]; then
  CURSOR=true
fi

# ── Determine recommended ─────────────────────────────────────────────────────
# Priority: opencode > claude_code > codex > none
RECOMMENDED="none"
if [[ "$OPENCODE" == "true" ]]; then
  RECOMMENDED="opencode"
elif [[ "$CLAUDE_CODE" == "true" ]]; then
  RECOMMENDED="claude_code"
elif [[ "$CODEX" == "true" ]]; then
  RECOMMENDED="codex"
fi

# ── Output JSON ───────────────────────────────────────────────────────────────
# Build JSON directly, converting bash booleans and handling null versions
python3 - \
  "$OPENCODE" "$CLAUDE_CODE" "$CODEX" "$CURSOR" "$RECOMMENDED" \
  "${OC_VERSION//\"}" "${CC_VERSION//\"}" "${CODEX_VERSION//\"}" << 'PYEOF'
import json, sys
oc_raw, cc_raw, cx_raw, cu_raw, rec, oc_v, cc_v, cx_v = sys.argv[1:]
result = {
    "opencode":    oc_raw == "true",
    "claude_code": cc_raw == "true",
    "codex":       cx_raw == "true",
    "cursor":      cu_raw == "true",
    "recommended": rec,
    "version": {
        "opencode":    oc_v if oc_v != "null" else None,
        "claude_code": cc_v if cc_v != "null" else None,
        "codex":       cx_v if cx_v != "null" else None,
    }
}
print(json.dumps(result, indent=2))
PYEOF

# ── Exit code ─────────────────────────────────────────────────────────────────
if [[ "$OPENCODE" == "false" && "$CLAUDE_CODE" == "false" && "$CODEX" == "false" && "$CURSOR" == "false" ]]; then
  exit 1
fi
exit 0
