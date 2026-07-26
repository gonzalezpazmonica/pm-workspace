#!/usr/bin/env bash
# skills-tier-audit.sh — SE-270 Slice 2 — Skill tier assignment audit
#
# Assigns tier: core to skills referenced by agents or commands.
# Assigns tier: extended to the rest.
# Generates output/skills-tier-report.json
#
# Usage:
#   bash scripts/skills-tier-audit.sh               # generate report
#   bash scripts/skills-tier-audit.sh --check        # verify report is current
#   bash scripts/skills-tier-audit.sh --json         # JSON to stdout
#
# Exit 0 on success, exit 1 on --check mismatch.
# Ref: SE-270

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -n "${SAVIA_SKILLS_DIR:-}" ]]; then
  SKILLS_DIR="$SAVIA_SKILLS_DIR"
else
  SKILLS_DIR="$(cd -P "$ROOT/.opencode/skills" && pwd)"
fi

AGENTS_DIR="$ROOT/.opencode/agents"
COMMANDS_DIR="$ROOT/.claude/commands"
OUTPUT_DIR="$ROOT/output"
REPORT_FILE="$OUTPUT_DIR/skills-tier-report.json"

MODE_CHECK=false
MODE_JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE_CHECK=true ;;
    --json)  MODE_JSON=true ;;
    --help|-h)
      sed -n '2,14p' "$0" | sed 's/^# //'
      exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

# ── Collect all skill names ────────────────────────────────────────────────────
mapfile -t all_skills < <(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d | while read -r d; do bname="$(basename "$d")"; [[ "$bname" != "_template" ]] && echo "$bname"; done | sort)

declare -A tier_map
for s in "${all_skills[@]}"; do
  tier_map["$s"]="extended"
done

# ── Mark core: skills referenced by agents ─────────────────────────────────────
if [[ -d "$AGENTS_DIR" ]]; then
  for agent_md in "$AGENTS_DIR"/*.md; do
    [[ ! -f "$agent_md" ]] && continue
    for skill_name in "${all_skills[@]}"; do
      if grep -q "$skill_name" "$agent_md" 2>/dev/null; then
        tier_map["$skill_name"]="core"
      fi
    done
    while IFS= read -r line; do
      if [[ "$line" =~ skills/ ]]; then
        for match in $(echo "$line" | grep -oE '[a-z][a-z0-9-]*' | while read -r w; do
          if [[ -n "${tier_map[$w]+x}" ]]; then echo "$w"; fi
        done); do
          tier_map["$match"]="core"
        done
      fi
    done < "$agent_md"
  done
fi

# ── Mark core: skills referenced by commands ───────────────────────────────────
if [[ -d "$COMMANDS_DIR" ]]; then
  for cmd_md in "$COMMANDS_DIR"/*.md; do
    [[ ! -f "$cmd_md" ]] && continue
    for skill_name in "${all_skills[@]}"; do
      if grep -q "$skill_name" "$cmd_md" 2>/dev/null; then
        tier_map["$skill_name"]="core"
      fi
    done
  done
fi

# ── Build JSON ─────────────────────────────────────────────────────────────────
core_count=0
extended_count=0
tier_json=""

for s in "${all_skills[@]}"; do
  tier="${tier_map[$s]}"
  if [[ "$tier" == "core" ]]; then core_count=$((core_count + 1)); else extended_count=$((extended_count + 1)); fi
  if [[ -n "$tier_json" ]]; then tier_json+=","; fi
  tier_json+="$(
    printf '\n    {"skill": "%s", "tier": "%s"}' "$s" "$tier"
  )"
done

json_output="{\"generated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"summary\": {\"core\": $core_count, \"extended\": $extended_count, \"total\": ${#all_skills[@]}}, \"skills\": [$tier_json
]}"

if $MODE_CHECK; then
  if [[ ! -f "$REPORT_FILE" ]]; then
    echo "CHECK FAIL: report file missing at $REPORT_FILE" >&2
    exit 1
  fi
  current_hash=$(echo "$json_output" | md5sum | cut -d' ' -f1)
  stored_hash=$(cat "$REPORT_FILE" | md5sum | cut -d' ' -f1)
  if [[ "$current_hash" != "$stored_hash" ]]; then
    echo "CHECK FAIL: $REPORT_FILE is stale. Re-run without --check." >&2
    exit 1
  fi
  echo "CHECK OK: $REPORT_FILE is current."
  exit 0
fi

if $MODE_JSON; then
  echo "$json_output"
else
  echo "$json_output"
fi

mkdir -p "$OUTPUT_DIR"
echo "$json_output" > "$REPORT_FILE"
echo "Report written: $REPORT_FILE" >&2
echo "Core: $core_count | Extended: $extended_count | Total: ${#all_skills[@]}" >&2
