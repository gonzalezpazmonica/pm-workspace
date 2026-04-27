#!/usr/bin/env bash
set -uo pipefail
# build-azdo-schema-graph.sh — SE-076 Slice 2
#
# Builds a JSON graph of an Azure DevOps project's schema:
#   nodes: {Field, AreaPath, IterationPath, WorkItemType, AllowedValue}
#   edges: HAS_FIELD, BELONGS_TO_AREA, ALLOWED_VALUE
#
# The NL→WIQL skill loads this graph BEFORE generating queries so it cannot
# invent Area Paths, Iteration Paths, or fields that don't exist on the
# referenced work-item type. This eliminates a whole class of WIQL invalid-
# query errors at the source instead of catching them after the fact.
#
# Usage:
#   bash scripts/build-azdo-schema-graph.sh --org <name> --project <name>
#   bash scripts/build-azdo-schema-graph.sh --from-fixtures <dir>     # offline mode
#   bash scripts/build-azdo-schema-graph.sh --validate <graph.json>
#
# Env:
#   AZURE_DEVOPS_ORG_URL      e.g. https://dev.azure.com/MyOrg
#   AZURE_DEVOPS_PAT_FILE     default $HOME/.azure/devops-pat (Rule #1)
#   AZURE_DEVOPS_API_VERSION  default 7.1
#   AZDO_SCHEMA_GRAPH_FILE    default ${ROOT}/output/azdo-schema-graph.json
#
# Exit codes:
#   0 ok | 2 usage error | 3 API/auth error | 4 fixture error | 5 validation fail
#
# Reference: SE-076 Slice 2 (docs/propuestas/SE-076-queryweaver-patterns.md)
# Reference: docs/rules/domain/autonomous-safety.md
# Reference: docs/rules/domain/savia-enterprise/agent-credentials.md (Rule #1)

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ORG=""
PROJECT=""
FROM_FIXTURES=""
VALIDATE_FILE=""
OUTPUT="${AZDO_SCHEMA_GRAPH_FILE:-${ROOT}/output/azdo-schema-graph.json}"
API_VERSION="${AZURE_DEVOPS_API_VERSION:-7.1}"

usage() {
  cat <<USG
Usage: build-azdo-schema-graph.sh --org <name> --project <name> [--output <path>]
       build-azdo-schema-graph.sh --from-fixtures <dir> [--output <path>]
       build-azdo-schema-graph.sh --validate <graph.json>

Modes:
  Live     Fetch schema from Azure DevOps REST API (requires PAT)
  Offline  Build from JSON fixtures in <dir>: fields.json, areas.json,
           iterations.json, work-item-types.json
  Validate Verify a graph file structurally (nodes + edges arrays present)

Env:
  AZURE_DEVOPS_ORG_URL      \${AZURE_DEVOPS_ORG_URL:-(unset)}
  AZURE_DEVOPS_PAT_FILE     \${AZURE_DEVOPS_PAT_FILE:-\$HOME/.azure/devops-pat}
  AZDO_SCHEMA_GRAPH_FILE    ${OUTPUT}
USG
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)            ORG="${2:?}"; shift 2 ;;
    --project)        PROJECT="${2:?}"; shift 2 ;;
    --from-fixtures)  FROM_FIXTURES="${2:?}"; shift 2 ;;
    --validate)       VALIDATE_FILE="${2:?}"; shift 2 ;;
    --output)         OUTPUT="${2:?}"; shift 2 ;;
    --help|-h)        usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# ── Validate mode ────────────────────────────────────────────────────────────

if [[ -n "$VALIDATE_FILE" ]]; then
  [[ -f "$VALIDATE_FILE" ]] || { echo "ERROR: graph file not found: $VALIDATE_FILE" >&2; exit 5; }
  python3 - "$VALIDATE_FILE" <<'PY' || exit 5
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"ERROR: invalid JSON: {e}", file=sys.stderr); sys.exit(5)
if not isinstance(d.get("nodes"), list) or not isinstance(d.get("edges"), list):
    print("ERROR: graph must have 'nodes' and 'edges' arrays", file=sys.stderr); sys.exit(5)
node_types = {n.get("type") for n in d["nodes"] if isinstance(n, dict)}
edge_types = {e.get("type") for e in d["edges"] if isinstance(e, dict)}
print(f"OK: nodes={len(d['nodes'])} edges={len(d['edges'])}")
print(f"     node_types={sorted(t for t in node_types if t)}")
print(f"     edge_types={sorted(t for t in edge_types if t)}")
PY
  exit 0
fi

# ── Fixture mode (offline; for tests) ────────────────────────────────────────

build_from_fixtures() {
  local dir="$1"
  [[ -d "$dir" ]] || { echo "ERROR: fixture dir not found: $dir" >&2; exit 4; }
  python3 - "$dir" "$OUTPUT" <<'PY'
import json, sys, os
fix_dir, out_path = sys.argv[1], sys.argv[2]
def _load(name):
    p = os.path.join(fix_dir, name)
    if not os.path.exists(p):
        return []
    try:
        d = json.load(open(p))
    except Exception:
        return []
    return d.get("value", d) if isinstance(d, dict) else d

fields = _load("fields.json")
areas = _load("areas.json")
iters = _load("iterations.json")
wits = _load("work-item-types.json")

nodes, edges = [], []
seen = set()
def add_node(nid, ntype, **rest):
    key = (ntype, nid)
    if key in seen: return
    seen.add(key)
    n = {"id": nid, "type": ntype}
    n.update(rest)
    nodes.append(n)

# Fields
for f in fields:
    if not isinstance(f, dict): continue
    rn = f.get("referenceName") or f.get("name")
    if not rn: continue
    add_node(rn, "Field", name=f.get("name", rn), type_hint=f.get("type"))

# Area Paths (recursive children)
def walk(node, parent_id, kind):
    if not isinstance(node, dict): return
    pid = node.get("path") or node.get("name")
    if not pid: return
    add_node(pid, kind, name=node.get("name"))
    if parent_id:
        edges.append({"from": parent_id, "to": pid, "type": "PARENT_OF"})
    for child in (node.get("children") or []):
        walk(child, pid, kind)

for a in areas:
    walk(a, None, "AreaPath")
for it in iters:
    walk(it, None, "IterationPath")

# Work item types + their fields
for w in wits:
    if not isinstance(w, dict): continue
    name = w.get("name")
    if not name: continue
    add_node(name, "WorkItemType", description=w.get("description"))
    for fr in (w.get("fields") or []):
        rn = fr.get("referenceName") if isinstance(fr, dict) else fr
        if not rn: continue
        if (("Field", rn) not in seen):
            add_node(rn, "Field", name=rn)
        edges.append({"from": name, "to": rn, "type": "HAS_FIELD"})

# Allowed values: from field allowedValues array
for f in fields:
    if not isinstance(f, dict): continue
    rn = f.get("referenceName") or f.get("name")
    for v in (f.get("allowedValues") or []):
        v_id = f"{rn}:{v}"
        add_node(v_id, "AllowedValue", value=v, field=rn)
        edges.append({"from": rn, "to": v_id, "type": "ALLOWED_VALUE"})

graph = {
    "nodes": nodes,
    "edges": edges,
    "generated_at": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "source": "fixtures",
}
os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
json.dump(graph, open(out_path, "w"), indent=2, ensure_ascii=False)
print(f"wrote {out_path}: nodes={len(nodes)} edges={len(edges)}")
PY
}

if [[ -n "$FROM_FIXTURES" ]]; then
  build_from_fixtures "$FROM_FIXTURES"
  exit 0
fi

# ── Live mode ────────────────────────────────────────────────────────────────

[[ -z "$ORG" || -z "$PROJECT" ]] && { echo "ERROR: --org and --project required" >&2; usage >&2; exit 2; }
PAT_FILE="${AZURE_DEVOPS_PAT_FILE:-$HOME/.azure/devops-pat}"
[[ -f "$PAT_FILE" ]] || { echo "ERROR: PAT file not found: $PAT_FILE" >&2; exit 3; }
PAT=$(cat "$PAT_FILE")
AUTH=$(printf ':%s' "$PAT" | base64 -w0)
BASE="https://dev.azure.com/${ORG}/${PROJECT}/_apis"
WORK_BASE="https://dev.azure.com/${ORG}/${PROJECT}/_apis/wit"

fetch() {
  local url="$1"
  curl -fsSL -H "Authorization: Basic ${AUTH}" -H "Accept: application/json" "$url" 2>/dev/null
}

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

if ! fetch "${WORK_BASE}/fields?api-version=${API_VERSION}" > "$WORK_DIR/fields.json"; then
  echo "ERROR: fetch fields failed (auth or org/project unreachable)" >&2; exit 3
fi
fetch "${WORK_BASE}/classificationnodes/Areas?\$depth=10&api-version=${API_VERSION}" > "$WORK_DIR/areas.json" || echo '{"children":[]}' > "$WORK_DIR/areas.json"
fetch "${WORK_BASE}/classificationnodes/Iterations?\$depth=10&api-version=${API_VERSION}" > "$WORK_DIR/iterations.json" || echo '{"children":[]}' > "$WORK_DIR/iterations.json"
fetch "${WORK_BASE}/workitemtypes?\$expand=fields&api-version=${API_VERSION}" > "$WORK_DIR/work-item-types.json" || echo '{"value":[]}' > "$WORK_DIR/work-item-types.json"

# Reuse the fixture builder on the just-fetched files
build_from_fixtures "$WORK_DIR"
