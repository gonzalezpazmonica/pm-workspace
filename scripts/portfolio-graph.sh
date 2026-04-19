#!/usr/bin/env bash
# portfolio-graph.sh — SPEC-SE-020 Slice 2 dependency graph builder.
#
# Escanea todos los `deps.yaml` en `<root>/<project-name>/deps.yaml` y
# construye el grafo de dependencias cross-project, rendereado como ASCII
# o Mermaid. Computed, not stored — zero egress.
#
# Usage:
#   portfolio-graph.sh --root projects/
#   portfolio-graph.sh --root projects/ --format mermaid
#   portfolio-graph.sh --root projects/ --json
#
# Exit codes:
#   0 — graph rendered (incluso si no hay deps encontradas)
#   2 — usage error
#
# Ref: SPEC-SE-020 §Portfolio graph, ROADMAP §Tier 5.12
# Dep: ninguna (standalone). Lee YAML con grep/sed.
# Safety: read-only, set -uo pipefail.

set -uo pipefail

ROOT=""
FORMAT="ascii"
JSON=0

usage() {
  cat <<EOF
Usage:
  $0 --root DIR [--format ascii|mermaid] [--json]

  --root DIR      Directorio con subcarpetas <project>/deps.yaml
  --format        'ascii' (default), 'mermaid'
  --json          Output JSON (nodes + edges)

Ref: SPEC-SE-020 §Portfolio graph
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$ROOT" ]] && { echo "ERROR: --root required" >&2; exit 2; }
[[ ! -d "$ROOT" ]] && { echo "ERROR: root directory not found: $ROOT" >&2; exit 2; }

case "$FORMAT" in
  ascii|mermaid) ;;
  *) echo "ERROR: invalid --format '$FORMAT' (allowed: ascii, mermaid)" >&2; exit 2 ;;
esac

# Collect all deps.yaml files under root.
mapfile -t DEPS_FILES < <(find "$ROOT" -mindepth 2 -maxdepth 2 -name 'deps.yaml' 2>/dev/null | sort)
N_FILES=${#DEPS_FILES[@]}

# Arrays to collect nodes (projects) and edges (from → to via type:deliverable).
declare -A PROJECTS_SEEN
NODES=()
EDGES=()

# Parse one deps.yaml: emit project name + upstream deps as lines.
parse_deps() {
  local file="$1"
  local proj
  proj=$(grep -E '^project:' "$file" | head -1 | sed -E 's/^project:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')
  proj="${proj// /}"
  [[ -z "$proj" ]] && return

  # Track project node.
  if [[ -z "${PROJECTS_SEEN[$proj]:-}" ]]; then
    PROJECTS_SEEN[$proj]=1
    NODES+=("$proj")
  fi

  # Walk upstream section: lines that start with "    - project:" under upstream:.
  # We use awk to collect tuples (upstream_project, type, status).
  local in_upstream=0
  local cur_project="" cur_type="" cur_status=""
  while IFS= read -r line; do
    # Top-level section detection.
    if [[ "$line" =~ ^[[:space:]]{2}upstream: ]]; then
      in_upstream=1; continue
    fi
    if [[ "$line" =~ ^[[:space:]]{2}(downstream|shared_resources): ]]; then
      in_upstream=0; continue
    fi
    [[ "$in_upstream" -ne 1 ]] && continue
    # New upstream entry starts with "    - project:".
    if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+project:[[:space:]]+\"?([^\"]+)\"? ]]; then
      # Flush previous.
      if [[ -n "$cur_project" ]]; then
        EDGES+=("$cur_project|$proj|$cur_type|$cur_status")
        # Also register upstream project as node.
        if [[ -z "${PROJECTS_SEEN[$cur_project]:-}" ]]; then
          PROJECTS_SEEN[$cur_project]=1
          NODES+=("$cur_project")
        fi
      fi
      cur_project="${BASH_REMATCH[1]}"
      cur_project="${cur_project// /}"
      cur_type=""; cur_status=""
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]+type:[[:space:]]+\"?([^\"]+)\"? ]]; then
      cur_type="${BASH_REMATCH[1]}"; cur_type="${cur_type// /}"
    fi
    if [[ "$line" =~ ^[[:space:]]+status:[[:space:]]+\"?([^\"]+)\"? ]]; then
      cur_status="${BASH_REMATCH[1]}"; cur_status="${cur_status// /}"
    fi
  done < "$file"
  # Flush last.
  if [[ -n "$cur_project" ]]; then
    EDGES+=("$cur_project|$proj|$cur_type|$cur_status")
    if [[ -z "${PROJECTS_SEEN[$cur_project]:-}" ]]; then
      PROJECTS_SEEN[$cur_project]=1
      NODES+=("$cur_project")
    fi
  fi
}

for f in "${DEPS_FILES[@]}"; do
  parse_deps "$f"
done

# Render output.
N_NODES=${#NODES[@]}
N_EDGES=${#EDGES[@]}

if [[ "$JSON" -eq 1 ]]; then
  # Nodes JSON.
  nodes_json=""
  for n in "${NODES[@]}"; do
    n_esc=$(echo "$n" | sed 's/"/\\"/g')
    nodes_json+="\"$n_esc\","
  done
  nodes_json="${nodes_json%,}"
  # Edges JSON.
  edges_json=""
  for e in "${EDGES[@]}"; do
    IFS='|' read -r from to etype est <<< "$e"
    edges_json+="{\"from\":\"$from\",\"to\":\"$to\",\"type\":\"$etype\",\"status\":\"$est\"},"
  done
  edges_json="${edges_json%,}"
  cat <<JSON
{"root":"$ROOT","n_files":$N_FILES,"n_nodes":$N_NODES,"n_edges":$N_EDGES,"nodes":[$nodes_json],"edges":[$edges_json]}
JSON
  exit 0
fi

if [[ "$FORMAT" == "mermaid" ]]; then
  echo "graph LR"
  for n in "${NODES[@]}"; do
    echo "  ${n//-/_}[\"$n\"]"
  done
  for e in "${EDGES[@]}"; do
    IFS='|' read -r from to etype est <<< "$e"
    f_id="${from//-/_}"
    t_id="${to//-/_}"
    label="$etype"
    [[ -n "$est" && "$est" != "on-track" ]] && label+=" ($est)"
    echo "  ${f_id} -->|${label}| ${t_id}"
  done
  exit 0
fi

# ASCII default.
echo "=== Portfolio Graph ==="
echo "Root:       $ROOT"
echo "Files:      $N_FILES deps.yaml parsed"
echo "Nodes:      $N_NODES projects"
echo "Edges:      $N_EDGES dependencies"
echo ""

if [[ "$N_NODES" -eq 0 ]]; then
  echo "(no deps.yaml found under $ROOT)"
  exit 0
fi

echo "Projects:"
for n in "${NODES[@]}"; do
  echo "  • $n"
done

if [[ "$N_EDGES" -gt 0 ]]; then
  echo ""
  echo "Dependencies (upstream → downstream):"
  for e in "${EDGES[@]}"; do
    IFS='|' read -r from to etype est <<< "$e"
    status_badge=""
    case "$est" in
      at-risk)  status_badge=" [AT-RISK]" ;;
      blocked)  status_badge=" [BLOCKED]" ;;
      delivered) status_badge=" [DELIVERED]" ;;
    esac
    echo "  $from --[$etype]--> $to${status_badge}"
  done
fi

exit 0
