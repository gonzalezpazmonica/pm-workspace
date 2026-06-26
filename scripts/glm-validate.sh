#!/usr/bin/env bash
# glm-validate.sh — Validates the GLM governance manifest for drift and completeness.
set -uo pipefail
#
# Checks:
#   1. .well-known/governance-layer-manifest.json exists and is valid JSON
#   2. .opencode/governance-manifest.yaml exists
#   3. All constraint enforcement paths exist in the repo
#   4. ethical_principles reference exists
#   5. audit.last_audit is within 90 days
#   6. manifest_digest.value is not placeholder
#
# Output: PASS | WARN (items with drift) | FAIL
# Exit codes: 0=PASS, 1=WARN, 2=FAIL

set -uo pipefail

MANIFEST=".well-known/governance-layer-manifest.json"
YAML_MANIFEST=".opencode/governance-manifest.yaml"
PASS=0
WARN=0
FAIL=0
ISSUES=()

pass() { echo "  PASS $1"; }
warn() { WARN=$((WARN+1)); ISSUES+=("WARN: $1"); echo "  WARN $1"; }
fail() { FAIL=$((FAIL+1)); ISSUES+=("FAIL: $1"); echo "  FAIL $1"; }

echo "=== GLM Manifest Validation ==="
echo ""

# Check 1: JSON manifest exists and is valid
echo "[1] JSON manifest"
if [[ ! -f "$MANIFEST" ]]; then
  fail "$MANIFEST not found"
else
  if python3 -m json.tool "$MANIFEST" > /dev/null 2>&1; then
    pass "$MANIFEST valid JSON"
  else
    fail "$MANIFEST is not valid JSON"
  fi
fi

# Check 2: YAML manifest exists
echo "[2] YAML manifest"
if [[ ! -f "$YAML_MANIFEST" ]]; then
  warn "$YAML_MANIFEST not found (optional operational manifest)"
else
  pass "$YAML_MANIFEST present"
fi

# Check 3: Constraint enforcement paths (YAML manifest)
echo "[3] Constraint enforcement paths"
ENFORCEMENT_PATHS=(
  ".opencode/hooks/block-credential-leak.sh"
  "scripts/savia-env.sh"
  "scripts/spec-approval-gate.sh"
  ".opencode/agents/commit-guardian.md"
)
for path in "${ENFORCEMENT_PATHS[@]}"; do
  if [[ -e "$path" ]]; then
    pass "$path"
  else
    warn "enforcement path missing: $path"
  fi
done

# Check 4: ethical_principles reference exists
echo "[4] Ethical framework reference"
ETHICS_REF="docs/rules/domain/savia-ethical-principles.md"
if [[ -f "$ETHICS_REF" ]]; then
  pass "$ETHICS_REF"
else
  fail "ethical principles reference missing: $ETHICS_REF"
fi

# Check 5: audit.last_audit recency (< 90 days)
echo "[5] Audit recency"
if [[ -f "$MANIFEST" ]]; then
  LAST_AUDIT=$(python3 -c "
import json, sys
try:
    data = json.load(open('$MANIFEST'))
    print(data.get('governance_metadata', {}).get('last_reviewed', ''))
except: pass
" 2>/dev/null)
  if [[ -z "$LAST_AUDIT" ]]; then
    warn "last_reviewed not found in manifest"
  else
    AUDIT_TS=$(date -d "$LAST_AUDIT" +%s 2>/dev/null || echo "0")
    NOW_TS=$(date +%s)
    DAYS=$(( (NOW_TS - AUDIT_TS) / 86400 ))
    if [[ "$DAYS" -le 90 ]]; then
      pass "last_reviewed $LAST_AUDIT (${DAYS}d ago)"
    else
      warn "last_reviewed $LAST_AUDIT is ${DAYS}d ago (>90 days — review due)"
    fi
  fi
fi

# Check 6: manifest_digest not placeholder
echo "[6] Manifest digest"
if [[ -f "$MANIFEST" ]]; then
  DIGEST_VAL=$(python3 -c "
import json
data = json.load(open('$MANIFEST'))
print(data.get('manifest_digest', {}).get('value', ''))
" 2>/dev/null)
  if [[ "$DIGEST_VAL" == "<computed>" || -z "$DIGEST_VAL" ]]; then
    warn "manifest_digest.value is placeholder — run scripts/glm-compute-digest.sh"
  else
    pass "manifest_digest.value present: ${DIGEST_VAL:0:16}..."
  fi
fi

# Check 7: surfaces anchors exist
echo "[7] Surface anchor files"
ANCHORS=(
  "docs/rules/domain/audit-trail-schema.md"
  "docs/savia-shield.md"
  "docs/rules/domain/verification-policy.md"
  "docs/rules/domain/pr-signing-protocol.md"
  ".opencode/skills/verification-lattice/SKILL.md"
)
for anchor in "${ANCHORS[@]}"; do
  if [[ -e "$anchor" ]]; then
    pass "$anchor"
  else
    warn "surface anchor missing: $anchor"
  fi
done

# Summary
echo ""
echo "=== Summary ==="
if [[ ${#ISSUES[@]} -gt 0 ]]; then
  for issue in "${ISSUES[@]}"; do
    echo "  $issue"
  done
fi
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "FAIL ($FAIL failures, $WARN warnings)"
  exit 2
elif [[ "$WARN" -gt 0 ]]; then
  echo "WARN ($WARN warnings)"
  exit 1
else
  echo "PASS (all checks passed)"
  exit 0
fi
