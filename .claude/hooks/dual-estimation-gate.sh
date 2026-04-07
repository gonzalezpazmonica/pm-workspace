#!/usr/bin/env bash
set -uo pipefail

# dual-estimation-gate.sh — SPEC-078 Phase 1
# PostToolUse hook: warns if spec/PBI has effort estimation
# but is missing dual scale (agent + human).
# Tier: standard | Exit: always 0 (warning only, never blocks)

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh"
  profile_gate "standard"
fi

# Read tool input from stdin
input=$(cat)

file_path=$(echo "$input" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4 2>/dev/null || true)
[[ -z "$file_path" ]] && exit 0

# Filter: only spec/PBI/task files
case "$file_path" in
  *.spec.md|*/backlog/pbi/*.md|*/backlog/task/*.md) ;;
  *) exit 0 ;;
esac

[[ ! -f "$file_path" ]] && exit 0

content=$(cat "$file_path" 2>/dev/null || true)
[[ -z "$content" ]] && exit 0

# Check if file has ANY estimation
if ! echo "$content" | grep -qiE "(effort|esfuerzo|estimat|hours|horas|minutes|minutos)"; then
  exit 0  # No estimation yet — draft stage, don't interrupt
fi

# Check for agent scale
has_agent=false
echo "$content" | grep -qiE "(agent.*(effort|min)|agent_effort|agente.*(esfuerzo|min))" && has_agent=true

# Check for human scale
has_human=false
echo "$content" | grep -qiE "(human.*(effort|hour|hora)|human_effort|humano.*(esfuerzo|hora))" && has_human=true

if [[ "$has_agent" == "true" && "$has_human" == "true" ]]; then
  exit 0  # Both scales present
fi

# Build warning
filename=$(basename "$file_path")
missing=""
[[ "$has_agent" == "false" ]] && missing="agent (agent_effort_minutes)"
[[ "$has_human" == "false" ]] && { [[ -n "$missing" ]] && missing="$missing + "; missing="${missing}human (human_effort_hours)"; }

echo "Dual Estimation: $filename tiene estimación pero falta escala $missing."
echo ""
echo "  Toda spec/PBI con estimación necesita las dos escalas:"
echo "    agent_effort_minutes:  XX   (tiempo real del agente)"
echo "    human_effort_hours:    XX   (tiempo equivalente humano)"
echo "    review_effort_minutes: XX   (revisión humana del output)"

exit 0
