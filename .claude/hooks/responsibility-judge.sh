#!/usr/bin/env bash
# responsibility-judge.sh — SPEC-043 Layer 1: deterministic shortcut detector
# Tier: standard (Layer 1 regex, zero latency)
# PreToolUse on Edit|Write — intercepts BEFORE shortcuts are written
set -uo pipefail

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh" && profile_gate "standard"
fi

[[ "${RESPONSIBILITY_JUDGE_ENABLED:-true}" == "false" ]] && exit 0

# Read hook input from stdin
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(timeout 3 cat 2>/dev/null) || true
fi
[[ -z "$INPUT" ]] && exit 0

# Extract file path and content from hook JSON
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    p = d.get('tool_input', {})
    print(p.get('file_path', p.get('path', '')))
except: pass
" 2>/dev/null)
[[ -z "$FILE_PATH" ]] && exit 0

CONTENT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    p = d.get('tool_input', {})
    c = p.get('content', p.get('new_string', ''))
    print(c[:3000])
except: pass
" 2>/dev/null)
[[ -z "$CONTENT" ]] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
AUDIT_LOG="$PROJECT_DIR/output/responsibility-judge.jsonl"
mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Override check
if [[ "${RESPONSIBILITY_JUDGE_OVERRIDE:-0}" == "1" ]]; then
  echo "{\"ts\":\"$TS\",\"file\":\"$FILE_PATH\",\"action\":\"OVERRIDE\"}" \
    >> "$AUDIT_LOG" 2>/dev/null
  exit 0
fi

PATTERN=""
DETAIL=""

# S-01: Threshold/limit lowered in test or config
if echo "$CONTENT" | grep -qiE \
  '(min_accuracy|accuracy_threshold|coverage_min|threshold)\s*[=:]\s*[0-9]*\.?[0-9]+'; then
  if echo "$FILE_PATH" | grep -qiE '(test|spec|config|bats|eval)'; then
    PATTERN="S-01"
    DETAIL="Threshold change in test/config file"
  fi
fi

# S-02: Test skipped or disabled
if [[ -z "$PATTERN" ]]; then
  if echo "$CONTENT" | grep -qiE \
    '(@Ignore|@Disabled|pytest\.mark\.skip|\.skip\(|xtest|xit\b|\[Skip\]|skip-bats)'; then
    PATTERN="S-02"
    DETAIL="Test skip/disable annotation added"
  fi
fi

# S-03: Empty error handler
if [[ -z "$PATTERN" ]]; then
  if echo "$CONTENT" | grep -qiE \
    '(catch\s*\{\s*\}|except:\s*pass|except\s+Exception.*pass|catch\s*\(.*\)\s*\{\s*\})'; then
    PATTERN="S-03"
    DETAIL="Empty error handler (swallowing errors)"
  fi
fi

# S-04: Quality gate bypass
if [[ -z "$PATTERN" ]]; then
  if echo "$CONTENT" | grep -qiE \
    '(--no-verify|--no-check|--skip-tests|--force-merge|\[skip-bats\]|--no-lint)'; then
    PATTERN="S-04"
    DETAIL="Quality gate bypass flag"
  fi
fi

# S-05: Coverage threshold reduced
if [[ -z "$PATTERN" ]]; then
  if echo "$CONTENT" | grep -qiE \
    '(coverage_min|min_percent|min_coverage)\s*[=:]\s*[0-9]+' ; then
    if echo "$FILE_PATH" | grep -qiE '(config|setting|pm-config)'; then
      PATTERN="S-05"
      DETAIL="Coverage threshold change in config"
    fi
  fi
fi

# S-06: TODO without ticket reference
if [[ -z "$PATTERN" ]]; then
  if echo "$CONTENT" | grep -qiE '(TODO|FIXME|HACK)\b' && \
     ! echo "$CONTENT" | grep -qiE '(TODO|FIXME|HACK)\s*[\(\[]\s*(AB#|@|#[0-9])'; then
    PATTERN="S-06"
    DETAIL="TODO/FIXME without ticket reference"
  fi
fi

# No pattern matched → pass
if [[ -z "$PATTERN" ]]; then
  exit 0
fi

# Pattern matched → log and block
echo "{\"ts\":\"$TS\",\"file\":\"$FILE_PATH\",\"pattern\":\"$PATTERN\",\"detail\":\"$DETAIL\",\"action\":\"BLOCKED\",\"override\":false}" \
  >> "$AUDIT_LOG" 2>/dev/null

cat >&2 <<EOF
RESPONSIBILITY JUDGE: Shortcut detected ($PATTERN — $DETAIL)
File: $FILE_PATH

Investigate WHY the failure occurs before changing acceptance criteria.
Override: RESPONSIBILITY_JUDGE_OVERRIDE=1 (logged to audit).
EOF

exit 2
