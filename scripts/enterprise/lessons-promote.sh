#!/usr/bin/env bash
# lessons-promote.sh — SE-032 Cross-Project Lessons Pipeline
# Promotes a cross-project lesson to a workspace rule.
#
# Usage:
#   scripts/enterprise/lessons-promote.sh --lesson-id ID --target DIR [--dry-run]
#
# Reads:  output/enterprise/cross-project-lessons-*.json  (latest)
# Output: Creates docs/rules/learned/{lesson-id}.md  (unless --dry-run)
#
# Requires human confirmation — never does push/merge automatically.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

LESSON_ID=""
TARGET_DIR="${REPO_ROOT}/docs/rules/learned"
DRY_RUN=false

# ── arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lesson-id) LESSON_ID="$2"; shift 2 ;;
    --target)    TARGET_DIR="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --help|-h)
      echo "Usage: lessons-promote.sh --lesson-id ID --target DIR [--dry-run]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$LESSON_ID" ]]; then
  echo "ERROR: --lesson-id is required" >&2
  exit 2
fi

# ── find latest lessons file ──────────────────────────────────────────────────
LESSONS_DIR="${REPO_ROOT}/output/enterprise"
LATEST_FILE=""
if [[ -d "$LESSONS_DIR" ]]; then
  LATEST_FILE="$(ls -t "${LESSONS_DIR}"/cross-project-lessons-*.json 2>/dev/null | head -1 || true)"
fi

if [[ -z "$LATEST_FILE" || ! -f "$LATEST_FILE" ]]; then
  echo "ERROR: No cross-project-lessons file found in ${LESSONS_DIR}" >&2
  echo "       Run lessons-collector.sh first." >&2
  exit 3
fi

# ── find lesson by ID ─────────────────────────────────────────────────────────
LESSON_TEXT=""
LESSON_TEXT="$(grep -A2 "\"${LESSON_ID}\"" "$LATEST_FILE" | grep 'representative_lesson' | cut -d'"' -f4 || true)"

if [[ -z "$LESSON_TEXT" ]]; then
  # Also try matching by theme
  LESSON_TEXT="$(grep -A3 "\"theme\": \"${LESSON_ID}\"" "$LATEST_FILE" | grep 'representative_lesson' | cut -d'"' -f4 || true)"
fi

if [[ -z "$LESSON_TEXT" ]]; then
  LESSON_TEXT="Lesson derived from cross-project pattern: ${LESSON_ID}"
fi

# ── build rule content ────────────────────────────────────────────────────────
RULE_FILE="${TARGET_DIR}/${LESSON_ID}.md"
RULE_CONTENT="---
date: $(date -u +%Y-%m-%d)
source: cross-project-lessons
lesson_id: \"${LESSON_ID}\"
promoted_by: \"lessons-promote.sh\"
status: PROPOSED
---

# Lesson: ${LESSON_ID}

${LESSON_TEXT}

## Origin

Promoted from cross-project lessons pipeline (SE-032).
Source file: $(basename "$LATEST_FILE")

## Human Review Required

This rule was proposed by an automated pipeline. A human must:
1. Review the lesson content above
2. Validate applicability to this workspace
3. Approve/reject before this file is merged

**Do not merge without human approval.**
"

# ── dry-run or apply ──────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY-RUN — would create: ${RULE_FILE}"
  echo "─────────────────────────────────────────"
  printf '%s\n' "$RULE_CONTENT"
  echo "─────────────────────────────────────────"
  echo "No file written (--dry-run active)."
  exit 0
fi

# Real mode: create the rule file
mkdir -p "$TARGET_DIR"

if [[ -f "$RULE_FILE" ]]; then
  echo "WARNING: ${RULE_FILE} already exists. Aborting to avoid overwrite." >&2
  exit 4
fi

printf '%s\n' "$RULE_CONTENT" > "$RULE_FILE"
echo "Rule created: ${RULE_FILE}"
echo "IMPORTANT: Human review required before merge."
