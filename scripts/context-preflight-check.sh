#!/usr/bin/env bash
set -uo pipefail
# ─────────────────────────────────────────────────────────────────────────────
# context-preflight-check.sh — SPEC-157 multi-source token estimator
#
# Estimates token load for a Task invocation from multiple sources:
#   1. Prompt text:         chars / 4
#   2. @-import file refs:  file_bytes / 4  (e.g. @docs/ROADMAP.md)
#   3. Skill refs:          SKILL.md bytes / 4 (skill names mentioned in prompt)
#   4. Agent context_window_target overhead
#
# Caches result by md5 of (agent + prompt) to avoid re-estimation.
#
# Args:    $1 = agent_name (required)
# Stdin:   prompt text
# Env:     PROJECT_DIR            (default: auto-detected from script location)
#          PREFLIGHT_CACHE_DIR    (default: /tmp/savia-preflight-cache)
# Output:  JSON to stdout
# Exit:    0 always (estimator never blocks — that is the hook's job)
#
# SPEC-157 Slice 1: Token estimator per input source.
# ─────────────────────────────────────────────────────────────────────────────

AGENT_NAME="${1:-}"
if [ -z "$AGENT_NAME" ]; then
  printf '{"error":"agent_name_required"}\n'
  exit 0
fi

PROMPT=$(cat 2>/dev/null || true)
if [ -z "$PROMPT" ]; then
  printf '{"error":"empty_prompt","agent":"%s"}\n' "$AGENT_NAME"
  exit 0
fi

# Auto-detect PROJECT_DIR from script location (scripts/ → repo root)
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(cd "$_SCRIPT_DIR/.." && pwd)}"

CACHE_DIR="${PREFLIGHT_CACHE_DIR:-/tmp/savia-preflight-cache}"
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# ── Cache lookup ──────────────────────────────────────────────────────────────
CACHE_KEY=$(printf '%s:%s' "$AGENT_NAME" "$PROMPT" | md5sum 2>/dev/null | cut -d' ' -f1 || true)
CACHE_FILE="$CACHE_DIR/${CACHE_KEY}.json"

if [ -n "$CACHE_KEY" ] && [ -f "$CACHE_FILE" ]; then
  cat "$CACHE_FILE"
  exit 0
fi

# ── Locate agent file ─────────────────────────────────────────────────────────
AGENT_FILE="$PROJECT_DIR/.opencode/agents/${AGENT_NAME}.md"
[ -f "$AGENT_FILE" ] || AGENT_FILE="$PROJECT_DIR/.claude/agents/${AGENT_NAME}.md"

if [ ! -f "$AGENT_FILE" ]; then
  printf '{"error":"agent_file_not_found","agent":"%s"}\n' "$AGENT_NAME"
  exit 0
fi

# ── Extract token_budget fields (block or flow YAML) ─────────────────────────
_extract_tb_field() {
  local file="$1" field="$2"
  local flow_line
  flow_line=$(grep -E '^token_budget:[[:space:]]*\{' "$file" | head -1 || true)
  if [ -n "$flow_line" ]; then
    echo "$flow_line" | grep -oE "${field}:[[:space:]]*[^,}]+" | head -1 \
      | sed -E "s/^${field}:[[:space:]]*//;s/[[:space:]\"]+\$//"
    return
  fi
  awk -v f="$field" '
    /^token_budget:[[:space:]]*$/ { in_tb=1; next }
    in_tb && /^[a-zA-Z_]/ && !/^[[:space:]]/ { in_tb=0 }
    in_tb && $0 ~ "^[[:space:]]+" f ":" {
      sub(".*" f ":[[:space:]]*",""); gsub(/[[:space:]"]/,""); print; exit
    }
  ' "$file"
}

PER_INV=$(_extract_tb_field "$AGENT_FILE" "per_invocation" | tr -dc '0-9')
CTX_TARGET=$(_extract_tb_field "$AGENT_FILE" "context_window_target" | tr -dc '0-9')
POLICY=$(_extract_tb_field "$AGENT_FILE" "escalation_policy" || true)
POLICY="${POLICY:-warn}"
CTX_TARGET="${CTX_TARGET:-0}"

if [ -z "$PER_INV" ]; then
  printf '{"error":"no_budget_declared","agent":"%s"}\n' "$AGENT_NAME"
  exit 0
fi

# ── 1. Prompt tokens ──────────────────────────────────────────────────────────
PROMPT_LEN="${#PROMPT}"
PROMPT_TOKENS=$(( PROMPT_LEN / 4 ))

# ── 2. @-import file reference tokens ────────────────────────────────────────
FILE_TOKENS=0
declare -A FILE_MAP 2>/dev/null || true
FILE_REFS_JSON="{"

while IFS= read -r ref; do
  clean="${ref#@}"
  sz=0
  if [ -f "$clean" ]; then
    sz=$(wc -c < "$clean" 2>/dev/null || echo 0)
  elif [ -f "$PROJECT_DIR/$clean" ]; then
    sz=$(wc -c < "$PROJECT_DIR/$clean" 2>/dev/null || echo 0)
  else
    continue
  fi
  toks=$(( sz / 4 ))
  FILE_TOKENS=$(( FILE_TOKENS + toks ))
  FILE_REFS_JSON="${FILE_REFS_JSON}\"${clean}\":${toks},"
done < <(grep -oE '@[./a-zA-Z0-9_-]+\.(md|sh|txt|json|yaml|yml)' <<< "$PROMPT" 2>/dev/null \
         | sort -u || true)

FILE_REFS_JSON="${FILE_REFS_JSON%,}}"
[ "$FILE_REFS_JSON" = "}" ] && FILE_REFS_JSON="{}"

# ── 3. Skill reference tokens ─────────────────────────────────────────────────
SKILL_TOKENS=0
SKILL_REFS_JSON="{"
SKILLS_DIR="$PROJECT_DIR/.opencode/skills"

if [ -d "$SKILLS_DIR" ]; then
  while IFS= read -r skill_dir; do
    skill_name=$(basename "$skill_dir")
    if printf '%s' "$PROMPT" | grep -qF "$skill_name" 2>/dev/null; then
      skill_file="$skill_dir/SKILL.md"
      if [ -f "$skill_file" ]; then
        sz=$(wc -c < "$skill_file" 2>/dev/null || echo 0)
        toks=$(( sz / 4 ))
        SKILL_TOKENS=$(( SKILL_TOKENS + toks ))
        SKILL_REFS_JSON="${SKILL_REFS_JSON}\"${skill_name}\":${toks},"
      fi
    fi
  done < <(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort || true)
fi

SKILL_REFS_JSON="${SKILL_REFS_JSON%,}}"
[ "$SKILL_REFS_JSON" = "}" ] && SKILL_REFS_JSON="{}"

# ── Total projection ──────────────────────────────────────────────────────────
PROJECTED=$(( PROMPT_TOKENS + CTX_TARGET + FILE_TOKENS + SKILL_TOKENS ))

# ── Verdict ───────────────────────────────────────────────────────────────────
VERDICT="ok"
if [ "$PROJECTED" -gt "$PER_INV" ]; then
  VERDICT="exceeded"
elif [ "$PROJECTED" -gt $(( PER_INV * 80 / 100 )) ]; then
  VERDICT="warn"
fi

# ── Suggestions ───────────────────────────────────────────────────────────────
if [ "$VERDICT" != "ok" ]; then
  SUGGESTIONS='["context-rot-strategy","context-task-classifier"]'
else
  SUGGESTIONS='[]'
fi

# ── Build + cache JSON ────────────────────────────────────────────────────────
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")

JSON=$(printf '{"ts":"%s","agent":"%s","budget":%d,"projected":%d,"verdict":"%s","policy":"%s","breakdown":{"prompt":%d,"context_target":%d,"files":%d,"skills":%d},"file_refs":%s,"skill_refs":%s,"suggestions":%s,"cache_key":"%s"}' \
  "$TS" "$AGENT_NAME" "$PER_INV" "$PROJECTED" "$VERDICT" "$POLICY" \
  "$PROMPT_TOKENS" "$CTX_TARGET" "$FILE_TOKENS" "$SKILL_TOKENS" \
  "$FILE_REFS_JSON" "$SKILL_REFS_JSON" "$SUGGESTIONS" "$CACHE_KEY")

if [ -n "$CACHE_KEY" ]; then
  printf '%s\n' "$JSON" > "$CACHE_FILE" 2>/dev/null || true
fi

printf '%s\n' "$JSON"
exit 0
