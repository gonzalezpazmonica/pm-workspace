#!/usr/bin/env bash
set -uo pipefail
# router-mode-dispatch.sh — SPEC-163 Slice 2
#
# PreToolUse hook that classifies Task tool calls as mode1 or mode2.
# Never blocks execution (always exit 0).
#
# Env vars:
#   SAVIA_ROUTER_MODE  off | shadow | enforce   (default: shadow)
#
# shadow  — classifies + logs to output/router-decisions.jsonl, exits 0
# enforce — classifies + logs + writes hint file when mode1 detected
# off     — no-op, exits 0 immediately
#
# Reference: SPEC-163 (docs/propuestas/SPEC-163-router-mode-1-2.md)

ROUTER_MODE="${SAVIA_ROUTER_MODE:-shadow}"

# ── mode=off: skip everything ─────────────────────────────────────────────────
if [[ "$ROUTER_MODE" == "off" ]]; then
    exit 0
fi

# ── Locate repo root (resolve via this script's real path) ───────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

CLASSIFIER="$REPO_ROOT/scripts/router-mode-classifier.py"
TELEMETRY_FILE="$REPO_ROOT/output/router-decisions.jsonl"
TURN_ID="${CLAUDE_TURN_ID:-${SAVIA_TURN_ID:-$(date +%s%N 2>/dev/null | md5sum | cut -c1-8 || date +%s | md5sum | cut -c1-8)}}"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"

# ── Read hook input (stdin JSON from OpenCode hook contract) ─────────────────
INPUT="$(cat 2>/dev/null || true)"
if [[ -z "$INPUT" ]]; then
    INPUT="{}"
fi

# ── Extract intent + command from tool call payload via python inline ─────────
EXTRACT_PY="$REPO_ROOT/scripts/_router_extract_helper.py"

EXTRACTED="$(python3 "$EXTRACT_PY" <<< "$INPUT" 2>/dev/null)" || \
    EXTRACTED='{"intent":"","command":"","has_code_change":false,"estimated_tokens":0}'

if [[ -z "$EXTRACTED" ]]; then
    EXTRACTED='{"intent":"","command":"","has_code_change":false,"estimated_tokens":0}'
fi

# ── Run classifier ────────────────────────────────────────────────────────────
if [[ -x "$CLASSIFIER" ]]; then
    CLASSIFICATION="$(python3 "$CLASSIFIER" <<< "$EXTRACTED" 2>/dev/null)" || \
        CLASSIFICATION='{"mode":"mode2","confidence":1.0,"reason":"classifier error","complexity_tier":"auto"}'
else
    CLASSIFICATION='{"mode":"mode2","confidence":1.0,"reason":"classifier not found","complexity_tier":"auto"}'
fi

if [[ -z "$CLASSIFICATION" ]]; then
    CLASSIFICATION='{"mode":"mode2","confidence":1.0,"reason":"empty classifier output","complexity_tier":"auto"}'
fi

# ── Build and write telemetry entry ──────────────────────────────────────────
TELEMETRY_PY="$REPO_ROOT/scripts/_router_telemetry_helper.py"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

TELEMETRY_ENTRY="$(python3 "$TELEMETRY_PY" \
    "$TS" "$TURN_ID" "$SESSION_ID" "$ROUTER_MODE" \
    <<< "$EXTRACTED"$'\x1E'"$CLASSIFICATION" 2>/dev/null)" || true

if [[ -n "$TELEMETRY_ENTRY" ]]; then
    mkdir -p "$(dirname "$TELEMETRY_FILE")" 2>/dev/null || true
    printf '%s\n' "$TELEMETRY_ENTRY" >> "$TELEMETRY_FILE" 2>/dev/null || true
fi

# ── enforce mode: write hint file for mode1 decisions ────────────────────────
if [[ "$ROUTER_MODE" == "enforce" ]]; then
    DETECTED_MODE="$(python3 -c "import json,sys; d=json.loads('$CLASSIFICATION'); print(d.get('mode','mode2'))" 2>/dev/null || echo "mode2")"
    if [[ "$DETECTED_MODE" == "mode1" ]]; then
        HINT_FILE="${TMPDIR:-/tmp}/savia-router-hint-${TURN_ID}"
        printf '[ROUTER_MODE1]\n' > "$HINT_FILE" 2>/dev/null || true
        export SAVIA_ROUTER_HINT="mode1"
    fi
fi

# ── Always exit 0 — never block ───────────────────────────────────────────────
exit 0
