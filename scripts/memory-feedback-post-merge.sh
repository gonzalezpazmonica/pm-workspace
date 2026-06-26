#!/usr/bin/env bash
# memory-feedback-post-merge.sh — Writes a memory entry when a PR is merged.
set -uo pipefail
# Spec: SPEC-164 Slice 2
#
# Usage modes:
#   1. As post-merge git hook (symlink to .git/hooks/post-merge)
#   2. Standalone: bash scripts/memory-feedback-post-merge.sh --manual --pr NNN --spec SE-NNN
#
# Install as git hook:
#   ln -sf "$(pwd)/scripts/memory-feedback-post-merge.sh" .git/hooks/post-merge
#   chmod +x .git/hooks/post-merge
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
MEMORY_STORE="${ROOT_DIR}/scripts/memory-store.sh"
TELEMETRY="${ROOT_DIR}/output/memory-feedback-telemetry.jsonl"

# ── Defaults ──────────────────────────────────────────────────────────────────
MANUAL_MODE=false
MANUAL_PR=""
MANUAL_SPEC=""
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── Parse arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "${1:-}" in
        --manual) MANUAL_MODE=true; shift ;;
        --pr)     MANUAL_PR="${2:-}"; shift 2 ;;
        --spec)   MANUAL_SPEC="${2:-}"; shift 2 ;;
        *) shift ;;
    esac
done

# ── Detect PR merge from git log ──────────────────────────────────────────────
detect_merge() {
    local last_commit
    last_commit=$(git -C "$ROOT_DIR" log --oneline -1 2>/dev/null || true)
    [[ -z "$last_commit" ]] && return 1

    # Detect merge commit patterns: "Merge pull request" or "Merged PR"
    if echo "$last_commit" | grep -qiE "Merge pull request|Merged PR|merged"; then
        echo "$last_commit"
        return 0
    fi
    return 1
}

extract_pr_number() {
    local msg="$1"
    # Match #NNN or PR NNN
    echo "$msg" | grep -oE '#[0-9]+' | head -1 || true
}

extract_spec_id() {
    local msg="$1"
    # Match SPEC-NNN or SE-NNN
    echo "$msg" | grep -oE '(SPEC|SE)-[0-9]+' | head -1 || true
}

extract_branch() {
    # Try to extract from merge message "from repo/branch"
    local msg="$1"
    echo "$msg" | grep -oE 'from [^ ]+' | sed 's/from //' | head -1 || true
}

# ── Memory store availability ─────────────────────────────────────────────────
if [[ ! -f "$MEMORY_STORE" ]]; then
    exit 0
fi

mkdir -p "$(dirname "$TELEMETRY")"

# ── Manual mode ───────────────────────────────────────────────────────────────
if [[ "$MANUAL_MODE" == "true" ]]; then
    PR_NUMBER="${MANUAL_PR:+#${MANUAL_PR}}"
    [[ -z "$PR_NUMBER" ]] && PR_NUMBER="(unknown)"
    SPEC_ID="${MANUAL_SPEC:-none}"
    BRANCH="manual"

    ENTRY="pr_merged:${PR_NUMBER} spec:${SPEC_ID} branch:${BRANCH} [${TS}]"
    bash "$MEMORY_STORE" save \
        --type "decision" \
        --title "pr_merged:${PR_NUMBER} spec:${SPEC_ID}" \
        --content "$ENTRY" \
        --concepts "pr,merge,${SPEC_ID}" \
        2>/dev/null || true

    printf '{"ts":"%s","source":"memory-feedback-post-merge","pr":"%s","spec":"%s","mode":"manual","written":true}\n' \
        "$TS" "$PR_NUMBER" "$SPEC_ID" >> "$TELEMETRY" 2>/dev/null || true
    exit 0
fi

# ── Auto mode (git hook) ──────────────────────────────────────────────────────
MERGE_MSG=$(detect_merge) || { exit 0; }

# Get full commit message for richer extraction
FULL_MSG=$(git -C "$ROOT_DIR" log --format="%B" -1 2>/dev/null || true)

PR_NUMBER=$(extract_pr_number "$FULL_MSG")
[[ -z "$PR_NUMBER" ]] && PR_NUMBER=$(extract_pr_number "$MERGE_MSG")
[[ -z "$PR_NUMBER" ]] && PR_NUMBER="(unknown)"

SPEC_ID=$(extract_spec_id "$FULL_MSG")
[[ -z "$SPEC_ID" ]] && SPEC_ID=$(extract_spec_id "$MERGE_MSG")
[[ -z "$SPEC_ID" ]] && SPEC_ID="none"

BRANCH=$(extract_branch "$FULL_MSG")
[[ -z "$BRANCH" ]] && BRANCH="unknown"

ENTRY="pr_merged:${PR_NUMBER} spec:${SPEC_ID} branch:${BRANCH} [${TS}]"

bash "$MEMORY_STORE" save \
    --type "decision" \
    --title "pr_merged:${PR_NUMBER} spec:${SPEC_ID}" \
    --content "$ENTRY" \
    --concepts "pr,merge,${SPEC_ID}" \
    2>/dev/null || true

printf '{"ts":"%s","source":"memory-feedback-post-merge","pr":"%s","spec":"%s","branch":"%s","mode":"auto","written":true}\n' \
    "$TS" "$PR_NUMBER" "$SPEC_ID" "$BRANCH" >> "$TELEMETRY" 2>/dev/null || true

exit 0
