#!/usr/bin/env bash
set -uo pipefail
# sync-github-metadata.sh — Update GitHub repo metadata
# SPEC: SE-011 (AC11-13)
# Idempotent: safe to run multiple times.

command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required" >&2; exit 2; }

REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null) || { echo "ERROR: not in a GitHub repo" >&2; exit 2; }
echo "Syncing metadata for: $REPO"

# Description
DESCRIPTION="Sovereign agentic architecture for PMs and dev teams. MIT. Zero vendor lock-in. Core + opt-in Enterprise modules."
echo "  Description: $DESCRIPTION"
gh repo edit "$REPO" --description "$DESCRIPTION" 2>/dev/null || echo "  WARN: could not update description"

# Topics
TOPICS="agentic,mcp,ai-sovereignty,spec-driven-development,ai-act,enterprise-ai,agent-framework,claude-code,project-management,devops"
echo "  Topics: $TOPICS"
for topic in ${TOPICS//,/ }; do
  gh repo edit "$REPO" --add-topic "$topic" 2>/dev/null || true
done

# Homepage (docs/enterprise/overview.md on GitHub)
HOMEPAGE="https://github.com/$REPO/blob/main/docs/enterprise/overview.md"
echo "  Homepage: $HOMEPAGE"
gh repo edit "$REPO" --homepage "$HOMEPAGE" 2>/dev/null || echo "  WARN: could not update homepage"

echo "Done."
