#!/bin/bash
set -uo pipefail
# nd-autoconfig.sh — SPEC-061: Auto-configure accessibility.md from neurodivergent.md
# Usage: nd-autoconfig.sh <neurodivergent.md> <accessibility.md>
# Runs in background during session-init. Silent on success.

ND_FILE="${1:-}"
ACC_FILE="${2:-}"

[[ -z "$ND_FILE" || -z "$ACC_FILE" ]] && exit 0
[[ ! -f "$ND_FILE" ]] && exit 0
[[ ! -f "$ACC_FILE" ]] && exit 0

CHANGED=false

# Helper: read value from a YAML section (section_name, field_name)
nd_section_val() {
  local section="$1" field="$2"
  awk -v sec="^${section}:" -v fld="${field}:" '
    $0 ~ sec { in_sec=1; next }
    in_sec && /^[a-z]/ { in_sec=0 }
    in_sec && $0 ~ fld { sub(/.*: */, ""); print; exit }
  ' "$ND_FILE" 2>/dev/null || echo ""
}
acc_val() { grep -oP "^\s*$1:\s*\K\S+" "$ACC_FILE" 2>/dev/null || echo ""; }

# Helper: set value in accessibility.md (only if different)
acc_set() {
  local key="$1" val="$2"
  local current
  current=$(acc_val "$key")
  if [[ "$current" != "$val" ]]; then
    if grep -q "^\s*${key}:" "$ACC_FILE" 2>/dev/null; then
      sed -i "s|^\(\s*${key}:\s*\).*|\1${val}|" "$ACC_FILE"
    fi
    CHANGED=true
  fi
}

# ── ADHD: RSD sensitivity → review_sensitivity ──
adhd_present=$(nd_section_val "adhd" "present")
if [[ "$adhd_present" == "true" ]]; then
  rsd=$(nd_section_val "adhd" "rsd_sensitivity")
  if [[ "$rsd" == "high" || "$rsd" == "very_high" ]]; then
    acc_set "review_sensitivity" "true"
  fi
fi

# ── Dyslexia → dyslexia_friendly ──
dyslexia_present=$(nd_section_val "dyslexia" "present")
if [[ "$dyslexia_present" == "true" ]]; then
  acc_set "dyslexia_friendly" "true"
fi

# ── Giftedness → cognitive_load: high ──
gift_present=$(nd_section_val "giftedness" "present")
if [[ "$gift_present" == "true" ]]; then
  acc_set "cognitive_load" "high"
fi

# ── Active modes → guided_work, focus_mode ──
MODES=$(grep -oP 'active_modes:\s*\[\K[^\]]+' "$ND_FILE" 2>/dev/null || echo "")
if [[ -n "$MODES" ]]; then
  if echo "$MODES" | grep -q 'structure'; then
    acc_set "guided_work" "true"
  fi
  if echo "$MODES" | grep -q 'focus_enhanced'; then
    acc_set "focus_mode" "true"
  fi
fi

# ── Dyscalculia: no accessibility.md field, handled at output time by rule ──

# ── Sensory budget → export env vars for context-health integration ──
SENSORY_BATCH=$(nd_section_val "sensory_budget" "batch_notifications")
SENSORY_PCT=$(nd_section_val "sensory_budget" "alert_at_percent")
if [[ "$SENSORY_BATCH" == "true" && -n "$SENSORY_PCT" ]]; then
  ENV_FILE="${CLAUDE_ENV_FILE:-}"
  if [[ -n "$ENV_FILE" ]]; then
    echo "export SAVIA_SENSORY_BATCH=true" >> "$ENV_FILE"
    echo "export SAVIA_SENSORY_ALERT_PCT=$SENSORY_PCT" >> "$ENV_FILE"
  fi
fi

# ── Communication preferences → export for meeting-agenda ceremony_preview ──
CEREMONY=$(nd_section_val "communication" "ceremony_preview")
if [[ "$CEREMONY" == "true" ]]; then
  ENV_FILE="${CLAUDE_ENV_FILE:-}"
  if [[ -n "$ENV_FILE" ]]; then
    echo "export SAVIA_CEREMONY_PREVIEW=true" >> "$ENV_FILE"
  fi
fi

# ── Time blindness → export for output footer timestamps ──
TIME_BLIND=$(nd_section_val "time" "time_blindness_markers")
if [[ "$TIME_BLIND" == "true" ]]; then
  ENV_FILE="${CLAUDE_ENV_FILE:-}"
  if [[ -n "$ENV_FILE" ]]; then
    echo "export SAVIA_TIME_MARKERS=true" >> "$ENV_FILE"
  fi
fi

exit 0
