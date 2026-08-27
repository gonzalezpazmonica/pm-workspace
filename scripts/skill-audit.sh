#!/bin/bash
set -uo pipefail
# skill-audit.sh — Baseline skill catalog quality auditor (SE-084 Slice 1)
#   + Agent Plugins / Agent Skills compliance mode (SE-333)
#
# Usage:
#   bash scripts/skill-audit.sh [--check] [--strict]
#   bash scripts/skill-audit.sh --agent-plugins [--strict] [--json]
#
# Modes:
#   (default)          Baseline quality audit (SE-084).
#   --agent-plugins    Validate conformance vs agent-plugins.org / agentskills.io
#                      (name, description, metadata.savia.*, plugin.json, mcp.json).
#   --strict           Upgrade warnings to errors (used by CI gate, SE-333 AC-9).
#   --json             Machine-readable output for CI (agent-plugins mode).

STRICT=false
AGENT_PLUGINS=false
JSON_MODE=false
for arg in "$@"; do
  case "$arg" in
    --strict)        STRICT=true ;;
    --agent-plugins) AGENT_PLUGINS=true ;;
    --json)          JSON_MODE=true ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${SKILLS_DIR:-$ROOT/.claude/skills}"
PASS=0
FAIL=0
WARN=0
JSON_FAILURES=()

json_emit() {
  if $JSON_MODE; then
    printf '%s' "$1"
  else
    printf '%s\n' "$1"
  fi
}

# ── Agent Plugins / Agent Skills conformance audit (SE-333) ──────────────────
if $AGENT_PLUGINS; then
  NAME_RX='^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]$'
  PROPS_TOPLEVEL=(
    summary maturity context context_cost agent category priority loop_level
    tags consumes produces trigger dependencies memory se references
    developer_type model authorization_required output_max_tokens
    max_context_tokens attribution version token_budget recommends globs
    bioquimica context_tier disable-model-invocation user-invocable argument-hint
  )

  # Validate a single SKILL.md frontmatter
  validate_skill() {
    local skill_dir="$1" skill_md="$1/SKILL.md"
    local skill errs=0 warns=0 name desc
    skill=$(basename "$skill_dir")

    [[ -f "$skill_md" ]] || { json_emit "  {\"skill\":\"$skill\",\"level\":\"error\",\"issue\":\"missing SKILL.md\"}\n"; return 1; }

    # name: exists, regex, dir-name match
    name=$(awk '/^---$/{c++;next} c==1&&/^name:/{sub(/^name:[[:space:]]*/,"");gsub(/["'"'"']/,"");print;exit}' "$skill_md")
    if [[ -z "$name" ]]; then
      json_emit "  {\"skill\":\"$skill\",\"level\":\"error\",\"issue\":\"missing name\"}\n"
      errs=$((errs+1))
    else
      if ! echo "$name" | grep -qE "$NAME_RX"; then
        json_emit "  {\"skill\":\"$skill\",\"level\":\"error\",\"issue\":\"name not kebab-lowercase: $name\"}\n"
        errs=$((errs+1))
      fi
      if [[ "$name" != "$skill" ]]; then
        json_emit "  {\"skill\":\"$skill\",\"level\":\"error\",\"issue\":\"name '$name' != dir '$skill'\"}\n"
        errs=$((errs+1))
      fi
    fi

    # description: exists, 1-1024 chars
    desc=$(awk '/^---$/{c++;next} c==1&&/^description:/{sub(/^description:[[:space:]]*/,"");gsub(/^"|"$/,"");print;exit}' "$skill_md")
    if [[ -z "$desc" ]]; then
      json_emit "  {\"skill\":\"$skill\",\"level\":\"error\",\"issue\":\"missing description\"}\n"
      errs=$((errs+1))
    elif [[ ${#desc} -gt 1024 ]]; then
      json_emit "  {\"skill\":\"$skill\",\"level\":\"error\",\"issue\":\"description ${#desc} chars > 1024\"}\n"
      errs=$((errs+1))
    fi

    # Proprietary top-level fields outside metadata: warn -> error in --strict
    local fm
    fm=$(awk '/^---$/{c++;next} c==1{print} c==2{exit}' "$skill_md")
    for prop in "${PROPS_TOPLEVEL[@]}"; do
      if echo "$fm" | grep -qE "^${prop}:[[:space:]]*[^[:space:]]"; then
        if $STRICT; then
          json_emit "  {\"skill\":\"$skill\",\"level\":\"error\",\"issue\":\"proprietary top-level '${prop}' not in metadata.savia.*\"}\n"
          errs=$((errs+1))
        else
          json_emit "  {\"skill\":\"$skill\",\"level\":\"warn\",\"issue\":\"proprietary top-level '${prop}' (migrate to metadata.savia.*)\"}\n"
          warns=$((warns+1))
        fi
      fi
    done

    [[ $errs -eq 0 ]] && return 0 || return 1
  }

  if $JSON_MODE; then
    printf '{\n  "mode": "agent-plugins",\n  "strict": %s,\n  "failures": [\n' "$($STRICT && echo true || echo false)"
  else
    echo "=== Agent Plugins / Agent Skills Compliance Audit (SE-333) ==="
    echo ""
  fi

  FAILURES=()
  for skill_dir in "$SKILLS_DIR"/*/; do
    skill=$(basename "$skill_dir")
    [[ "$skill" == "_template" || "$skill" == "_template_python" ]] && continue
    if validate_skill "$skill_dir"; then
      PASS=$((PASS+1))
    else
      FAIL=$((FAIL+1))
      FAILURES+=("$skill")
    fi
  done

  # Validate plugin.json (Agent Plugins manifest, closed schema subset)
  PLUGIN_JSON="$ROOT/plugin.json"
  if [[ -f "$PLUGIN_JSON" ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq -e 'has("$schema") and has("name") and (.name|type=="string") and (if has("extensions") then (.extensions|type=="object") else true end)' "$PLUGIN_JSON" >/dev/null 2>&1 \
        || { json_emit "  {\"file\":\"plugin.json\",\"level\":\"error\",\"issue\":\"plugin.json schema/name/extensions invalid\"}\n"; FAIL=$((FAIL+1)); }
    else
      grep -q '"$schema"' "$PLUGIN_JSON" && grep -q '"name"' "$PLUGIN_JSON" \
        || { json_emit "  {\"file\":\"plugin.json\",\"level\":\"error\",\"issue\":\"plugin.json missing \$schema/name\"}\n"; FAIL=$((FAIL+1)); }
    fi
  else
    json_emit "  {\"file\":\"plugin.json\",\"level\":\"error\",\"issue\":\"plugin.json missing\"}\n"
    FAIL=$((FAIL+1))
  fi

  # Validate mcp.json (portable, type declared, contained paths)
  MCP_JSON="$ROOT/mcp.json"
  if [[ -f "$MCP_JSON" ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq -e '.mcpServers and (.mcpServers|type=="object")' "$MCP_JSON" >/dev/null 2>&1 \
        || { json_emit "  {\"file\":\"mcp.json\",\"level\":\"error\",\"issue\":\"mcp.json missing mcpServers\"}\n"; FAIL=$((FAIL+1)); }
      # every server must declare a transport type
      jq -e '[.mcpServers[] | has("type")] | all' "$MCP_JSON" >/dev/null 2>&1 \
        || { json_emit "  {\"file\":\"mcp.json\",\"level\":\"error\",\"issue\":\"mcp server missing transport type\"}\n"; FAIL=$((FAIL+1)); }
    else
      grep -q 'type' "$MCP_JSON" || { json_emit "  {\"file\":\"mcp.json\",\"level\":\"error\",\"issue\":\"mcp.json no transport type\"}\n"; FAIL=$((FAIL+1)); }
    fi
  else
    json_emit "  {\"file\":\"mcp.json\",\"level\":\"warn\",\"issue\":\"mcp.json portable missing (optional)\"}\n"
    WARN=$((WARN+1))
  fi

  if $JSON_MODE; then
    printf '  ],\n  "summary": {"pass": %d, "fail": %d, "warn": %d}\n}\n' "$PASS" "$FAIL" "$WARN"
  else
    echo ""
    echo "=== Results ==="
    echo "  PASS: $PASS"
    echo "  WARN: $WARN"
    echo "  FAIL: $FAIL"
    echo "  Total: $((PASS + WARN + FAIL)) skills audited"
    echo ""
  fi

  [[ $FAIL -gt 0 ]] && exit 1
  exit 0
fi

# ── Baseline quality audit (SE-084) ──────────────────────────────────────────
echo "=== Skill Catalog Quality Audit ==="
echo ""

for skill_dir in "$SKILLS_DIR"/*/; do
  skill=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"
  issues=()

  # Check SKILL.md exists
  [[ ! -f "$skill_md" ]] && issues+=("MISSING SKILL.md") && FAIL=$((FAIL+1)) && continue

  # Check has YAML frontmatter (starts with ---)
  first_line=$(head -1 "$skill_md")
  [[ "$first_line" != "---" ]] && issues+=("no YAML frontmatter")

  # Check required frontmatter fields
  has_name=$(grep -c "^name:" "$skill_md" 2>/dev/null || echo 0)
  has_desc=$(grep -c "^description:" "$skill_md" 2>/dev/null || echo 0)
  [[ $has_name -eq 0 ]] && issues+=("missing 'name' field")
  [[ $has_desc -eq 0 ]] && issues+=("missing 'description' field")

  # Strict mode: check compatibility field
  if $STRICT; then
    has_compat=$(grep -c "^compatibility:" "$skill_md" 2>/dev/null || echo 0)
    [[ $has_compat -eq 0 ]] && issues+=("missing 'compatibility' field (provider-agnostic)")
  fi

  # Strict mode: check license
  if $STRICT; then
    has_license=$(grep -c "^license:" "$skill_md" 2>/dev/null || echo 0)
    [[ $has_license -eq 0 ]] && issues+=("missing 'license' field")
  fi

  # Check DOMAIN.md exists
  [[ ! -f "$skill_dir/DOMAIN.md" ]] && issues+=("missing DOMAIN.md")

  # Report
  if [[ ${#issues[@]} -eq 0 ]]; then
    PASS=$((PASS+1))
  elif [[ ${#issues[@]} -le 1 ]] && ! $STRICT; then
    echo "  WARN $skill: ${issues[*]}"
    WARN=$((WARN+1))
  else
    echo "  FAIL $skill: ${issues[*]}"
    FAIL=$((FAIL+1))
  fi
done

echo ""
echo "=== Results ==="
echo "  PASS: $PASS"
echo "  WARN: $WARN"
echo "  FAIL: $FAIL"
echo "  Total: $((PASS + WARN + FAIL)) skills audited"
echo ""

[[ $FAIL -gt 0 ]] && exit 1
exit 0
