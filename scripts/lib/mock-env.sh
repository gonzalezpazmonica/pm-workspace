#!/usr/bin/env bash
# mock-env.sh — Reusable mock environment library for pm-workspace scripts
# Source this from any script that needs to run without external dependencies.
#
# Usage:
#   source "$(dirname "$0")/lib/mock-env.sh"
#   mock_init              # Set up mock environment
#   mock_azure_response    # Returns mock Azure DevOps JSON
#   mock_mcp_response      # Returns mock MCP server JSON
#   is_mock_mode           # Returns 0 if in mock mode

MOCK_MODE="${PM_MOCK:-false}"
MOCK_DATA_DIR="${PM_MOCK_DATA:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/projects/sala-reservas/test-data}"

mock_init() {
  MOCK_MODE="true"
  export PM_MOCK="true"
  export PM_MOCK_DATA="$MOCK_DATA_DIR"
}

is_mock_mode() {
  [ "$MOCK_MODE" = "true" ]
}

mock_azure_response() {
  local endpoint="${1:-workitems}"
  local mock_file="$MOCK_DATA_DIR/mock-${endpoint}.json"
  if [ -f "$mock_file" ]; then
    cat "$mock_file"
  else
    echo '{"value": [], "count": 0}'
  fi
}

mock_mcp_response() {
  local tool="${1:-query}"
  echo "{\"mock\": true, \"tool\": \"$tool\", \"result\": {\"status\": \"ok\", \"data\": []}}"
}

mock_sprint_data() {
  cat << 'JSON'
{
  "id": "mock-sprint-42",
  "name": "Sprint 42",
  "startDate": "2026-03-01T00:00:00Z",
  "endDate": "2026-03-14T00:00:00Z",
  "state": "current",
  "workItems": {
    "total": 15,
    "completed": 8,
    "inProgress": 4,
    "todo": 3
  },
  "velocity": {
    "planned": 34,
    "completed": 21,
    "remaining": 13
  }
}
JSON
}

mock_team_data() {
  cat << 'JSON'
{
  "members": [
    {"name": "Dev A", "capacity": 6, "role": "developer"},
    {"name": "Dev B", "capacity": 6, "role": "developer"},
    {"name": "QA C", "capacity": 6, "role": "tester"},
    {"name": "PM D", "capacity": 4, "role": "pm"}
  ],
  "totalCapacity": 22,
  "sprintDays": 10
}
JSON
}

# Auto-detect mock mode from environment or --mock flag
for arg in "$@"; do
  [ "$arg" = "--mock" ] && mock_init
done
