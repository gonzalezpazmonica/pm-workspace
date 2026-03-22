#!/bin/bash
# competence-tracker.sh — Async PostToolUse hook: logs domain per command
# SPEC-014 Phase 2. Registered as async (never blocks user).
# Writes to .claude/profiles/users/{slug}/competence-log.jsonl

INPUT=""
INPUT=$(timeout 2 cat 2>/dev/null) || true
[[ -z "$INPUT" ]] && exit 0

# Only track Bash commands (slash commands appear as Bash tool calls)
TOOL=$(printf '%s' "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4 2>/dev/null)
[[ "$TOOL" != "Bash" && "$TOOL" != "bash" ]] && exit 0

CMD=$(printf '%s' "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null)
[[ -z "$CMD" ]] && exit 0

# ── Detect active user ───────────────────────────────────────────────────
SLUG=""
for p in "$HOME/claude/.claude/profiles" "$PWD/.claude/profiles"; do
  af="$p/active-user.md"
  [[ -f "$af" ]] && SLUG=$(grep -oP 'active_slug:\s*"\K[^"]+' "$af" 2>/dev/null) && break
done
[[ -z "$SLUG" ]] && exit 0

LOG_DIR="$HOME/claude/.claude/profiles/users/$SLUG"
[[ ! -d "$LOG_DIR" ]] && exit 0
LOG_FILE="$LOG_DIR/competence-log.jsonl"

# ── Map command to domain ────────────────────────────────────────────────
DOMAIN=""
case "$CMD" in
  *sprint-*|*daily-*|*velocity-*|*board-*|*burndown*|*capacity-*|*backlog-*)
    DOMAIN="sprint-mgmt" ;;
  *spec-*|*sdd-*|*dev-session*|*implement*)
    DOMAIN="sdd" ;;
  *arch-*|*adr-*|*diagram-*)
    DOMAIN="architecture" ;;
  *security-*|*a11y-*|*compliance-*|*aepd-*|*threat-*|*credential-*)
    DOMAIN="security" ;;
  *pipeline-*|*deploy-*|*infra-*|*repos-*)
    DOMAIN="devops" ;;
  *test-*|*spec-verify*|*coverage-*|*qa-*)
    DOMAIN="testing" ;;
  *report-*|*ceo-*|*stakeholder-*|*kpi-*|*dora-*)
    DOMAIN="reporting" ;;
  *pbi-*|*product-*|*jtbd-*|*prd-*|*epic-*)
    DOMAIN="product" ;;
  *memory-*|*context-*|*compact*|*nl-*)
    DOMAIN="context" ;;
  *team-*|*onboard*|*wellbeing*|*workload*)
    DOMAIN="team" ;;
  *zeroclaw*|*voice-*|*hw-*)
    DOMAIN="hardware" ;;
esac

[[ -z "$DOMAIN" ]] && exit 0

# ── Log entry ────────────────────────────────────────────────────────────
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -Iseconds)
echo "{\"ts\":\"$TS\",\"domain\":\"$DOMAIN\",\"cmd\":\"$CMD\",\"success\":true}" >> "$LOG_FILE"

# ── Rotate if >1000 entries ──────────────────────────────────────────────
LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
if [[ $LINES -gt 1000 ]]; then
  tail -500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

exit 0
