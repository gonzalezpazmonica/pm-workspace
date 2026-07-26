#!/usr/bin/env bash
# agent-depth-limit.sh — SE-270 Slice 4: Build agent invocation graph and check depth.
#
# Reads agent frontmatter for permission.task.allowlist declarations.
# Builds a directed invocation graph (who can call whom).
# Checks max depth ≤ 2 by default.
# Generates graph as Mermaid markdown. Also supports JSON format.
# Output path: docs/agent-invocation-graph.md
#
# Ref: SE-270
# Safety: set -uo pipefail. Read-only. No destructive ops.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
AGENTS_DIR="${AGENTS_DIR:-$REPO_ROOT/.opencode/agents}"
OUTPUT_DIR="$REPO_ROOT/docs"
OUTPUT_FILE="$OUTPUT_DIR/agent-invocation-graph.md"
MAX_DEPTH="${MAX_DEPTH:-2}"

usage() {
  cat <<EOF
Usage: $0 [--max-depth N] [--output PATH] [--format mermaid|json] [--quiet]

Builds agent invocation graph from permission.task.allowlist declarations.
Checks invocation chain depth against --max-depth (default: 2).

  --max-depth N    Maximum allowed invocation depth (default: 2).
  --output PATH    Output file path (default: $OUTPUT_FILE).
  --format FMT     Output format: mermaid (default) or json.
  --quiet          Suppress stdout summary.

Exit codes:
  0 — all invocation paths within max depth
  1 — one or more paths exceed max depth
  2 — usage error
EOF
}

QUIET=0
FORMAT="mermaid"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-depth) MAX_DEPTH="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

# ── Phase 1: Parse agent permission.task.allowlist declarations ────────────

declare -A AGENT_ALLOWLIST
AGENT_NAMES=()

parse_allowlist() {
  local file="$1"
  awk '
    /^---$/{ if(++c==2) exit; next }
    c==1 && /^permission\.task:/ { in_pt=1; next }
    in_pt && /^[[:space:]]+allowlist:/ {
      gsub(/^[[:space:]]*allowlist:[[:space:]]*[\[  \t]*/,"");
      gsub(/[\],][[:space:]]*$/,"");
      print;
      in_pt=0; exit
    }
    in_pt && /^[^[:space:]]/ { in_pt=0 }
    in_pt && /^[[:space:]]+[a-z]/ && !/allowlist/ { in_pt=0 }
  ' "$file" 2>/dev/null | tr -d '\n'
}

while IFS= read -r -d '' agent_file; do
  name=$(basename "$agent_file" .md)
  AGENT_NAMES+=("$name")
  allowlist=$(parse_allowlist "$agent_file")
  if [[ -n "$allowlist" ]]; then
    AGENT_ALLOWLIST["$name"]="$allowlist"
  fi
done < <(find "$AGENTS_DIR" -maxdepth 1 -type f -name '*.md' -print0 | sort -z)

# ── Phase 2: Build adjacency list ──────────────────────────────────────────

declare -A ADJACENCY
for caller in "${!AGENT_ALLOWLIST[@]}"; do
  targets="${AGENT_ALLOWLIST[$caller]}"
  if [[ -n "$targets" ]]; then
    cleaned=$(echo "$targets" | tr -d '[]"' | tr ',' '\n')
    while IFS= read -r callee; do
      callee=$(echo "$callee" | xargs)
      [[ -z "$callee" ]] && continue
      exists=0
      for a in "${AGENT_NAMES[@]}"; do
        if [[ "$a" == "$callee" ]]; then exists=1; break; fi
      done
      if [[ "$exists" -eq 1 ]]; then
        ADJACENCY["$caller"]+="$callee "
      fi
    done <<< "$cleaned"
  fi
done

# ── Phase 3: BFS-based depth check ─────────────────────────────────────────

MAX_DEPTH_VAL=0
DEEPEST_PATH=""

for root in "${!AGENT_ALLOWLIST[@]}"; do
  declare -A VLOCAL=()
  declare -A PLOCAL=()
  QUEUE=()
  QH=0
  QT=0

  QUEUE[$QT]="$root"
  QT=$((QT+1))
  VLOCAL["$root"]=0

  while [[ $QH -lt $QT ]]; do
    current="${QUEUE[$QH]}"
    QH=$((QH+1))
    d="${VLOCAL[$current]}"

    if [[ "$d" -gt "$MAX_DEPTH_VAL" ]]; then
      MAX_DEPTH_VAL=$d
      path="$current"
      p="$current"
      while [[ -n "${PLOCAL[$p]:-}" ]]; do
        path="${PLOCAL[$p]} → $path"
        p="${PLOCAL[$p]}"
      done
      DEEPEST_PATH="$path"
    fi

    for nxt in ${ADJACENCY[$current]:-}; do
      [[ -z "$nxt" || "$nxt" == "$current" ]] && continue
      if [[ -n "${VLOCAL[$nxt]:-}" ]]; then
        continue
      fi
      VLOCAL[$nxt]=$((d+1))
      PLOCAL[$nxt]="$current"
      QUEUE[$QT]="$nxt"
      QT=$((QT+1))
    done
  done
  unset VLOCAL PLOCAL QUEUE
done

# ── Phase 4: Generate output ───────────────────────────────────────────────

DATE_STR="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
NODES_WITH_EDGES="${#ADJACENCY[@]}"

if [[ "$FORMAT" == "json" ]]; then
  edges=""
  edge_count=0
  for caller in "${!ADJACENCY[@]}"; do
    for callee in ${ADJACENCY[$caller]:-}; do
      [[ -z "$callee" ]] && continue
      if [[ $edge_count -gt 0 ]]; then edges+=","; fi
      edges+="{\"from\":\"$caller\",\"to\":\"$callee\"}"
      edge_count=$((edge_count+1))
    done
  done

  depth_ok="true"
  [[ "$MAX_DEPTH_VAL" -gt "$MAX_DEPTH" ]] && depth_ok="false"

  cat > "$OUTPUT_FILE" << JSONEOF
{
  "title": "Agent Invocation Graph",
  "generated": "$DATE_STR",
  "ref": "SE-270",
  "max_detected_depth": $MAX_DEPTH_VAL,
  "max_allowed_depth": $MAX_DEPTH,
  "depth_ok": $depth_ok,
  "deepest_path": "$DEEPEST_PATH",
  "edges": [$edges],
  "edge_count": $edge_count,
  "nodes_with_delegation": $NODES_WITH_EDGES
}
JSONEOF

else
  depth_status="PASS"
  [[ "$MAX_DEPTH_VAL" -gt "$MAX_DEPTH" ]] && depth_status="FAIL"

  {
    echo "# Agent Invocation Graph"
    echo ""
    echo "> Generated: $DATE_STR | SE-270 Slice 4"
    echo "> Max detected depth: **$MAX_DEPTH_VAL** (limit: $MAX_DEPTH) — **$depth_status**"
    if [[ -n "$DEEPEST_PATH" ]]; then
      echo "> Deepest path: \`$DEEPEST_PATH\`"
    fi
    echo ""
    echo "## Graph"
    echo ""
    echo "\`\`\`mermaid"
    echo "graph TD"
    for caller in "${!ADJACENCY[@]}"; do
      for callee in ${ADJACENCY[$caller]:-}; do
        [[ -z "$callee" ]] && continue
        echo "    ${caller}[\"${caller}\"] --> ${callee}[\"${callee}\"]"
      done
    done
    echo "\`\`\`"
    echo ""
    echo "## Delegation Table"
    echo ""
    echo "| Caller | Allowed Targets |"
    echo "|---|---|"
    for caller in "${!ADJACENCY[@]}"; do
      targets_clean=$(echo "${ADJACENCY[$caller]:-}" | xargs | tr ' ' ', ')
      echo "| $caller | $targets_clean |"
    done
    echo ""
    echo "---"
    echo "Generated by scripts/agent-depth-limit.sh"
  } > "$OUTPUT_FILE"
fi

if [[ "$QUIET" -eq 0 ]]; then
  echo "agent-depth-limit: max_depth=$MAX_DEPTH_VAL (limit=$MAX_DEPTH) nodes_with_delegation=$NODES_WITH_EDGES"
  echo "  output: ${OUTPUT_FILE#$REPO_ROOT/}"
  if [[ "$MAX_DEPTH_VAL" -gt "$MAX_DEPTH" ]]; then
    echo "  FAIL: max invocation depth ($MAX_DEPTH_VAL) exceeds limit ($MAX_DEPTH)"
  else
    echo "  PASS: invocation depth within limit"
  fi
fi

if [[ "$MAX_DEPTH_VAL" -gt "$MAX_DEPTH" ]]; then
  exit 1
fi
exit 0
