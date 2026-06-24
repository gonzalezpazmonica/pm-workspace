#!/usr/bin/env bash
# security-auto-remediation.sh — SPEC-070: Security Auto-Remediation PRs
#
# Orchestrates the Red→Blue→PR pipeline for security findings.
#
# Usage:
#   bash scripts/security-auto-remediation.sh \
#       --finding "SQL injection in user login endpoint" \
#       --file "src/auth/login.py" \
#       [--severity high|medium|low]
#
# Output (JSON to stdout):
#   {finding, severity, fix_proposed, branch, pr_url_or_instructions}
#
# Master switch: SAVIA_AUTO_REMEDIATION=on|off (default off)
#
# NUNCA modifica código directamente — solo propone.
# Sigue autonomous-safety.md: ramas agent/*, PR Draft, AUTONOMOUS_REVIEWER.
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
FINDING=""
FILE_PATH=""
SEVERITY="medium"
SAVIA_AUTO_REMEDIATION="${SAVIA_AUTO_REMEDIATION:-off}"

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null || pwd)"
GENERATOR="$REPO_ROOT/scripts/security-remediation-generator.py"
OUTPUT_DIR="$REPO_ROOT/output/security-fixes"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --finding)   FINDING="$2";   shift 2 ;;
        --file)      FILE_PATH="$2"; shift 2 ;;
        --severity)  SEVERITY="$2";  shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$FINDING" ]]; then
    echo '{"error": "Missing --finding argument"}' >&2
    exit 1
fi

# ── Master switch ─────────────────────────────────────────────────────────────
if [[ "${SAVIA_AUTO_REMEDIATION}" != "on" ]]; then
    printf '{"status":"disabled","reason":"SAVIA_AUTO_REMEDIATION=off","finding":"%s"}\n' \
        "$(echo "$FINDING" | sed 's/"/\\"/g')"
    exit 0
fi

# ── Ensure output directory ───────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── Compute short hash for unique identifiers ─────────────────────────────────
HASH=$(printf '%s\n' "${FINDING}${FILE_PATH}$(date +%s)" | sha256sum | cut -c1-8)
DATE=$(date +%Y%m%d)

# ── Infer vulnerability type from finding description ────────────────────────
VULN_TYPE="unknown"
FINDING_LOWER=$(echo "$FINDING" | tr '[:upper:]' '[:lower:]')

if echo "$FINDING_LOWER" | grep -qE "sql.?inject|sqli"; then
    VULN_TYPE="sql-injection"
elif echo "$FINDING_LOWER" | grep -qE "xss|cross.?site.?script"; then
    VULN_TYPE="xss"
elif echo "$FINDING_LOWER" | grep -qE "hardcoded|hard.coded|api.?key|secret|credential|password.in.code"; then
    VULN_TYPE="hardcoded-cred"
elif echo "$FINDING_LOWER" | grep -qE "path.?travers|directory.?travers"; then
    VULN_TYPE="path-traversal"
elif echo "$FINDING_LOWER" | grep -qE "command.?inject|cmd.?inject|shell.?inject|os.inject"; then
    VULN_TYPE="command-injection"
elif echo "$FINDING_LOWER" | grep -qE "deserializ"; then
    VULN_TYPE="insecure-deserialization"
elif echo "$FINDING_LOWER" | grep -qE "csrf|cross.?site.?request"; then
    VULN_TYPE="csrf"
elif echo "$FINDING_LOWER" | grep -qE "sensitive.?data|data.?expos|pii.?leak"; then
    VULN_TYPE="sensitive-data-exposure"
elif echo "$FINDING_LOWER" | grep -qE "broken.?auth|auth.?bypass|weak.?auth"; then
    VULN_TYPE="broken-auth"
elif echo "$FINDING_LOWER" | grep -qE "redirect|open.?redirect"; then
    VULN_TYPE="open-redirect"
fi

# ── Step 1: Generate fix suggestion via security-remediation-generator ────────
if [[ ! -f "$GENERATOR" ]]; then
    echo '{"error": "security-remediation-generator.py not found"}' >&2
    exit 1
fi

FIX_JSON=$(python3 "$GENERATOR" --type "$VULN_TYPE" 2>/dev/null) || {
    echo '{"error": "generator failed"}' >&2
    exit 1
}

FIX_DESCRIPTION=$(echo "$FIX_JSON" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); print(d.get('fix_description',''))")
FIX_PATCH=$(echo "$FIX_JSON" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); print(d.get('code_patch_suggestion',''))")
FIX_CONFIDENCE=$(echo "$FIX_JSON" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); print(d.get('confidence', 0.0))")

# ── Step 2: Write fix to output/security-fixes/{hash}.md ─────────────────────
FIX_FILE="$OUTPUT_DIR/${HASH}.md"

cat > "$FIX_FILE" <<MDEOF
# Security Fix Proposal — ${DATE}

**Hash:** ${HASH}
**Severity:** ${SEVERITY}
**Vulnerability type:** ${VULN_TYPE}
**Affected file:** ${FILE_PATH:-"(not specified)"}

## Finding

${FINDING}

## Fix Description

${FIX_DESCRIPTION}

## Code Patch Suggestion

\`\`\`
${FIX_PATCH}
\`\`\`

## Confidence

${FIX_CONFIDENCE}

## Pipeline

security-attacker → security-remediation-generator → PR proposal

## Notes

- This is a PROPOSAL only. No code has been modified.
- Review and apply manually or via PR after human approval.
- Follow autonomous-safety.md: NEVER auto-merge.
MDEOF

# ── Step 3: For high severity — attempt to create branch and PR draft ─────────
BRANCH=""
PR_URL_OR_INSTRUCTIONS=""

if [[ "$SEVERITY" == "high" ]]; then
    BRANCH="agent/security-fix-${DATE}-${HASH}"

    # Attempt branch creation if inside a git repo
    if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$REPO_ROOT" branch "$BRANCH" 2>/dev/null || true
    fi

    # Step 4: Generate PR if gh CLI is available
    if command -v gh >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        AUTONOMOUS_REVIEWER="${AUTONOMOUS_REVIEWER:-@local-user}"
        PR_BODY="## Security Fixes — ${DATE}

### Finding
${FINDING}

### Vulnerability Type
${VULN_TYPE}

### Severity
${SEVERITY}

### Affected File
${FILE_PATH:-"(not specified)"}

### Fix Proposal
See \`output/security-fixes/${HASH}.md\`

### Pipeline
security-attacker → security-remediation-generator → PR

---
**This is a DRAFT PR. Review required before merge.**
Reviewer: ${AUTONOMOUS_REVIEWER}
"
        # Only attempt PR creation if the branch was actually created and pushed
        # (dry-run in most CI contexts — just output instructions)
        PR_URL_OR_INSTRUCTIONS="gh pr create --draft --title 'security(fix): ${VULN_TYPE} — ${HASH}' --body '...' --head '${BRANCH}' --reviewer '${AUTONOMOUS_REVIEWER}'"
    else
        PR_URL_OR_INSTRUCTIONS="gh pr create --draft --title 'security(fix): ${VULN_TYPE} — ${HASH}' --body '(see output/security-fixes/${HASH}.md)' --head '${BRANCH}'"
    fi
fi

# ── Output JSON ───────────────────────────────────────────────────────────────
python3 - <<PYEOF
import json
result = {
    "finding": """${FINDING}""",
    "severity": "${SEVERITY}",
    "vulnerability_type": "${VULN_TYPE}",
    "fix_proposed": """${FIX_DESCRIPTION}""",
    "fix_file": "${FIX_FILE}",
    "branch": "${BRANCH}",
    "pr_url_or_instructions": """${PR_URL_OR_INSTRUCTIONS}""",
    "confidence": ${FIX_CONFIDENCE},
}
print(json.dumps(result, indent=2))
PYEOF
