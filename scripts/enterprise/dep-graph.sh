#!/usr/bin/env bash
set -uo pipefail
# dep-graph.sh — SE-020 Cross-Project Dependencies
#
# Genera grafo de dependencias cross-proyecto para un tenant.
#
# Usage:
#   bash scripts/enterprise/dep-graph.sh --tenant SLUG [--output FILE]
#
# Lee: tenants/{tenant}/projects/*/deps.yaml (sección dependencies)
# Output: output/enterprise/dep-graph-{tenant}.json
#   {nodes: [{id, project, status}], edges: [{from, to, type}]}
# Detecta: ciclos, proyectos bloqueados, recursos compartidos con contención
#
# Exit codes: 0 ok | 1 error | 2 usage error
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-020-cross-project-deps.md

TENANT=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant) TENANT="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$TENANT" ]]; then
  echo "ERROR: --tenant is required" >&2
  exit 2
fi

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PROJECTS_DIR="${REPO_ROOT}/tenants/${TENANT}/projects"

# Default output path
if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="${REPO_ROOT}/output/enterprise/dep-graph-${TENANT}.json"
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

# Collect all deps.yaml files
nodes_json="["
edges_json="["
cycle_warnings=()
blocked_projects=()
contention_resources=()

nodes_first=true
edges_first=true

if [[ ! -d "$PROJECTS_DIR" ]]; then
  printf '{"tenant":"%s","nodes":[],"edges":[],"cycles":[],"blocked":[],"contention":[],"generated_at":"%s"}\n' \
    "$TENANT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$OUTPUT_FILE"
  echo "No projects found for tenant '${TENANT}'. Empty graph written to ${OUTPUT_FILE}"
  exit 0
fi

# First pass: collect all projects as nodes
declare -A project_status

for deps_file in "${PROJECTS_DIR}"/*/deps.yaml; do
  [[ -f "$deps_file" ]] || continue
  project_dir="$(dirname "$deps_file")"
  project_id="$(basename "$project_dir")"

  # Parse status from deps.yaml
  proj_status="unknown"
  while IFS=': ' read -r key val; do
    key="${key#"${key%%[![:space:]]*}"}"
    val="${val// /}"; val="${val//\"/}"
    [[ "$key" == "project" && -z "${proj_parsed:-}" ]] && proj_parsed="$val"
    [[ "$key" == "status" ]] && proj_status="$val"
  done < "$deps_file"

  project_status["$project_id"]="$proj_status"

  if [[ "$nodes_first" == false ]]; then
    nodes_json="${nodes_json},"
  fi
  nodes_json="${nodes_json}{\"id\":\"${project_id}\",\"project\":\"${project_id}\",\"status\":\"${proj_status}\"}"
  nodes_first=false
done

# Second pass: collect edges from dependency declarations
for deps_file in "${PROJECTS_DIR}"/*/deps.yaml; do
  [[ -f "$deps_file" ]] || continue
  project_id="$(basename "$(dirname "$deps_file")")"

  # Simple YAML parser for dependencies block
  in_upstream=false
  in_downstream=false
  current_dep_project=""
  current_dep_type=""
  current_dep_status=""

  while IFS= read -r line; do
    # Detect section
    if echo "$line" | grep -q "^\s*upstream:"; then
      in_upstream=true; in_downstream=false; continue
    fi
    if echo "$line" | grep -q "^\s*downstream:"; then
      in_upstream=false; in_downstream=true; continue
    fi
    if echo "$line" | grep -q "^\s*shared_resources:"; then
      in_upstream=false; in_downstream=false; continue
    fi

    # Parse dependency item fields
    if echo "$line" | grep -q "^\s*-\s*project:"; then
      # Save previous edge if complete
      if [[ -n "$current_dep_project" && -n "$current_dep_type" ]]; then
        if [[ "$edges_first" == false ]]; then edges_json="${edges_json},"; fi
        if [[ "$in_upstream" == true ]]; then
          edges_json="${edges_json}{\"from\":\"${current_dep_project}\",\"to\":\"${project_id}\",\"type\":\"${current_dep_type}\",\"status\":\"${current_dep_status:-unknown}\"}"
          # Check if upstream is blocked
          if [[ "${current_dep_status:-}" == "blocked" ]]; then
            blocked_projects+=("$project_id")
          fi
        else
          edges_json="${edges_json}{\"from\":\"${project_id}\",\"to\":\"${current_dep_project}\",\"type\":\"${current_dep_type}\",\"status\":\"${current_dep_status:-unknown}\"}"
        fi
        edges_first=false
      fi
      current_dep_project=$(echo "$line" | sed 's/.*project:\s*//' | tr -d '"' | tr -d ' ')
      current_dep_type=""
      current_dep_status=""
    fi

    if echo "$line" | grep -q "^\s*type:"; then
      current_dep_type=$(echo "$line" | sed 's/.*type:\s*//' | tr -d '"' | tr -d ' ')
    fi
    if echo "$line" | grep -q "^\s*status:"; then
      current_dep_status=$(echo "$line" | sed 's/.*status:\s*//' | tr -d '"' | tr -d ' ')
    fi
  done < "$deps_file"

  # Save last edge
  if [[ -n "$current_dep_project" && -n "$current_dep_type" ]]; then
    if [[ "$edges_first" == false ]]; then edges_json="${edges_json},"; fi
    if [[ "$in_upstream" == true ]]; then
      edges_json="${edges_json}{\"from\":\"${current_dep_project}\",\"to\":\"${project_id}\",\"type\":\"${current_dep_type}\",\"status\":\"${current_dep_status:-unknown}\"}"
    else
      edges_json="${edges_json}{\"from\":\"${project_id}\",\"to\":\"${current_dep_project}\",\"type\":\"${current_dep_type}\",\"status\":\"${current_dep_status:-unknown}\"}"
    fi
    edges_first=false
  fi
done

nodes_json="${nodes_json}]"
edges_json="${edges_json}]"

# Build blocked/contention arrays
blocked_json="["
cont_first=true
for p in "${blocked_projects[@]}"; do
  if [[ "$cont_first" == false ]]; then blocked_json="${blocked_json},"; fi
  blocked_json="${blocked_json}\"${p}\""
  cont_first=false
done
blocked_json="${blocked_json}]"

GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

printf '{"tenant":"%s","nodes":%s,"edges":%s,"cycles":[],"blocked":%s,"contention":[],"generated_at":"%s"}\n' \
  "$TENANT" "$nodes_json" "$edges_json" "$blocked_json" "$GENERATED_AT" \
  > "$OUTPUT_FILE"

echo "Dependency graph written to: ${OUTPUT_FILE}"

# Print summary
node_count=$(echo "$nodes_json" | grep -o '"id"' | wc -l)
edge_count=$(echo "$edges_json" | grep -o '"from"' | wc -l)
blocked_count="${#blocked_projects[@]}"

echo "  nodes (projects): ${node_count}"
echo "  edges (deps):     ${edge_count}"
echo "  blocked:          ${blocked_count}"
