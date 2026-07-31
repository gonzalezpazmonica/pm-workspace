#!/usr/bin/env bash
# Detector: drift-daily (SE-279)
# Lightweight drift check between docs, config, and code.
# Wraps existing drift-auditor patterns in a fast check.

set -uo pipefail

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DRIFT_COUNT=0
DRIFT_ITEMS="[]"

# Check 1: SKILLS.md sync
TMP_SKILLS=$(mktemp)
if bash "${ROOT}/scripts/skills-md-generate.sh" > "$TMP_SKILLS" 2>/dev/null; then
  if ! diff -q "$TMP_SKILLS" "${ROOT}/SKILLS.md" >/dev/null 2>&1; then
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
    DRIFT_ITEMS=$(echo "$DRIFT_ITEMS" | python3 -c "
import sys, json
items = json.load(sys.stdin)
items.append({'type':'skills_md_drift','description':'SKILLS.md out of sync with source'})
print(json.dumps(items))
" 2>/dev/null)
  fi
fi
rm -f "$TMP_SKILLS"

# Check 2: AGENTS.md sync
TMP_AGENTS=$(mktemp)
if bash "${ROOT}/scripts/agents-md-generate.sh" > "$TMP_AGENTS" 2>/dev/null; then
  if ! diff -q "$TMP_AGENTS" "${ROOT}/AGENTS.md" >/dev/null 2>&1; then
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
    DRIFT_ITEMS=$(echo "$DRIFT_ITEMS" | python3 -c "
import sys, json
items = json.load(sys.stdin)
items.append({'type':'agents_md_drift','description':'AGENTS.md out of sync with source'})
print(json.dumps(items))
" 2>/dev/null)
  fi
fi
rm -f "$TMP_AGENTS"

# Check 3: skills-manifest.json exists
if [[ ! -f "${ROOT}/skills-manifest.json" ]]; then
  DRIFT_COUNT=$((DRIFT_COUNT + 1))
  DRIFT_ITEMS=$(echo "$DRIFT_ITEMS" | python3 -c "
import sys, json
items = json.load(sys.stdin)
items.append({'type':'manifest_missing','description':'skills-manifest.json not found'})
print(json.dumps(items))
" 2>/dev/null)
fi

if [[ "$DRIFT_COUNT" -eq 0 ]]; then
  echo '{"triggered":false,"reason":"no drift detected"}'
else
  echo "{\"triggered\":true,\"detector\":\"drift-daily\",\"count\":$DRIFT_COUNT,\"items\":$DRIFT_ITEMS,\"summary\":\"$DRIFT_COUNT drift issue(s) detected\"}"
fi
