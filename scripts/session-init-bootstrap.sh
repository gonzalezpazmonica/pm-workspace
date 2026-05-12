#!/bin/bash
set -uo pipefail
# session-init-bootstrap.sh — SE-045 Slice 1 async bootstrap.
#
# Runs detached in background. Does the heavy work that was blocking
# session-init:
#   - Ollama /api/tags probe + pre-warm
#   - Shield /health probe x2
#   - Skill manifest rebuild
#   - SCM regen
#   - Memory hygiene
#   - Context rotation
#
# Writes aggregated state to ~/.pm-workspace/session-state-cache.json.
# The fast-path (session-init.sh) reads this cache on next invocation.
#
# Never blocks. Never fails (all errors swallowed).
#
# Ref: SE-045, audit-arquitectura-20260420.md §riesgo 1

CACHE_DIR="$HOME/.pm-workspace"
CACHE_FILE="$CACHE_DIR/session-state-cache.json"
CACHE_TMP="$CACHE_DIR/.session-state-cache.tmp.$$"
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Collect state (all fast OR already-async)
OLLAMA_STATUS="offline"
SHIELD_STATUS="offline"
SHIELD_PROXY_STATUS="offline"

# Ollama probe — very short timeout (500ms), tolerate failure
if command -v curl >/dev/null 2>&1; then
  if curl -s --max-time 0.5 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    OLLAMA_STATUS="online"
    # Pre-warm the model in the background (not waiting for it)
    curl -s --max-time 3 http://127.0.0.1:11434/api/generate \
      -d '{"model":"qwen2.5:7b","prompt":"hi","stream":false,"options":{"num_predict":1}}' \
      >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi

  SHIELD_PORT="${SAVIA_SHIELD_PORT:-8444}"
  SHIELD_PROXY_PORT="${SAVIA_SHIELD_PROXY_PORT:-8443}"
  if curl -sf --max-time 0.5 "http://127.0.0.1:$SHIELD_PORT/health" >/dev/null 2>&1; then
    SHIELD_STATUS="online"
  fi
  if curl -sf --max-time 0.5 "http://127.0.0.1:$SHIELD_PROXY_PORT/health" >/dev/null 2>&1; then
    SHIELD_PROXY_STATUS="online"
  fi
fi

# Skill manifest rebuild if stale
MANIFEST=".claude/skill-manifests.json"
if [[ ! -f "$MANIFEST" ]] || find .claude/skills -name "SKILL.md" -newer "$MANIFEST" 2>/dev/null | grep -q .; then
  bash scripts/build-skill-manifest.sh >/dev/null 2>&1 || true
fi

# SCM regen if stale
SCM_INDEX=".scm/INDEX.scm"
if [[ ! -f "$SCM_INDEX" ]] || \
   find .claude/commands .claude/skills .claude/agents scripts \
        \( -name "*.md" -o -name "*.sh" \) -newer "$SCM_INDEX" -print -quit 2>/dev/null | grep -q .; then
  python3 scripts/generate-capability-map.py >/dev/null 2>&1 || true
fi

# Memory hygiene
for mh_path in "$HOME/claude/scripts/memory-hygiene.sh" "./scripts/memory-hygiene.sh"; do
  [ -f "$mh_path" ] && bash "$mh_path" >/dev/null 2>&1 && break
done

# Context rotation
for cr_path in "$HOME/claude/scripts/context-rotation.sh" "./scripts/context-rotation.sh"; do
  if [ -f "$cr_path" ]; then
    bash "$cr_path" daily >/dev/null 2>&1 || true
    DOW=$(date +%u)
    [[ "$DOW" == "1" ]] && bash "$cr_path" weekly >/dev/null 2>&1 || true
    DOM=$(date +%d)
    [[ "$DOM" == "01" ]] && bash "$cr_path" monthly >/dev/null 2>&1 || true
    break
  fi
done

# Git merge drivers setup
if [[ -x "scripts/setup-merge-drivers.sh" ]]; then
  bash scripts/setup-merge-drivers.sh >/dev/null 2>&1 || true
fi

# Write cache atomically
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$CACHE_TMP" <<JSON
{
  "generated_at": "$TS",
  "ollama": "$OLLAMA_STATUS",
  "shield": "$SHIELD_STATUS",
  "shield_proxy": "$SHIELD_PROXY_STATUS"
}
JSON
mv "$CACHE_TMP" "$CACHE_FILE" 2>/dev/null || rm -f "$CACHE_TMP"

exit 0
