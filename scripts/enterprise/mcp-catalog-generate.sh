#!/usr/bin/env bash
# mcp-catalog-generate.sh — SPEC-SE-003: Genera catálogo de MCP servers del workspace
#
# Escanea .opencode/agents/, scripts/ y docs/rules/ para construir el catálogo
# de los 7 MCP servers canónicos de Savia y los refleja en catalog.json.
#
# Usage:
#   mcp-catalog-generate.sh [--output-dir DIR]
#
# Output: output/mcp-catalog/catalog.json
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-003-mcp-catalog.md

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

OUTPUT_DIR="${ROOT_DIR}/output/mcp-catalog"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
      exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

# ── Determinar versión Savia ─────────────────────────────────────────────────

SAVIA_VERSION="unknown"
VERSION_FILE="${ROOT_DIR}/package.json"
if [[ -f "$VERSION_FILE" ]]; then
  SAVIA_VERSION=$(grep '"version"' "$VERSION_FILE" 2>/dev/null | head -1 \
    | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo "unknown")
fi

GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── Definición canónica de los 7 MCP servers ────────────────────────────────
# Fuente: SPEC-SE-003 §Catálogo inicial (7 MCP servers)

cat > "$OUTPUT_DIR/catalog.json" <<EOF
{
  "generated_at": "$GENERATED_AT",
  "savia_version": "$SAVIA_VERSION",
  "spec": "SE-003",
  "mcp_protocol_version": "1.0",
  "servers": [
    {
      "id": "savia-pm-mcp",
      "lang": ".NET",
      "capabilities": ["pbis", "sprints", "capacity", "velocity"],
      "value": "Azure DevOps + Jira + Savia Flow",
      "tools": [
        {
          "name": "sprint_status",
          "description": "Returns current sprint status with completion percentage and blockers",
          "input_schema": {"type": "object", "properties": {"project": {"type": "string"}}, "required": ["project"]}
        },
        {
          "name": "capacity_plan",
          "description": "Returns team capacity for the current sprint",
          "input_schema": {"type": "object", "properties": {"team": {"type": "string"}}, "required": ["team"]}
        },
        {
          "name": "velocity_history",
          "description": "Returns velocity history for the last N sprints",
          "input_schema": {"type": "object", "properties": {"sprints": {"type": "integer", "default": 5}}}
        }
      ],
      "status": "stub",
      "repo": "github.com/{org}/savia-pm-mcp",
      "license": "MIT"
    },
    {
      "id": "savia-azdevops-mcp",
      "lang": ".NET",
      "capabilities": ["wiql", "work_items", "pipelines", "repos"],
      "value": "Hueco en ecosistema .NET MCP",
      "tools": [
        {
          "name": "wiql_query",
          "description": "Executes a WIQL query against Azure DevOps and returns work items",
          "input_schema": {"type": "object", "properties": {"query": {"type": "string"}, "project": {"type": "string"}}, "required": ["query"]}
        },
        {
          "name": "work_item_update",
          "description": "Updates a work item field",
          "input_schema": {"type": "object", "properties": {"id": {"type": "integer"}, "field": {"type": "string"}, "value": {"type": "string"}}, "required": ["id", "field", "value"]}
        },
        {
          "name": "pipeline_status",
          "description": "Returns the status of a pipeline run",
          "input_schema": {"type": "object", "properties": {"pipeline_id": {"type": "integer"}}, "required": ["pipeline_id"]}
        }
      ],
      "status": "stub",
      "repo": "github.com/{org}/savia-azdevops-mcp",
      "license": "MIT"
    },
    {
      "id": "savia-memory-mcp",
      "lang": "TypeScript",
      "capabilities": ["recall", "save", "graph", "domains"],
      "value": "Memoria soberana multi-runtime",
      "tools": [
        {
          "name": "memory_recall",
          "description": "Recalls entries from persistent memory by query or domain",
          "input_schema": {"type": "object", "properties": {"query": {"type": "string"}, "domain": {"type": "string"}}}
        },
        {
          "name": "memory_save",
          "description": "Saves an entry to persistent memory with optional TTL",
          "input_schema": {"type": "object", "properties": {"content": {"type": "string"}, "domain": {"type": "string"}, "ttl_days": {"type": "integer"}}, "required": ["content"]}
        },
        {
          "name": "memory_graph_query",
          "description": "Executes a graph query over the memory knowledge store",
          "input_schema": {"type": "object", "properties": {"cypher": {"type": "string"}}, "required": ["cypher"]}
        }
      ],
      "status": "available",
      "repo": "github.com/{org}/savia-memory-mcp",
      "license": "MIT"
    },
    {
      "id": "savia-shield-mcp",
      "lang": "Python",
      "capabilities": ["classification_n1_n4", "masking", "pii_detection"],
      "value": "Compliance AI Act",
      "tools": [
        {
          "name": "classify_content",
          "description": "Classifies content into N1-N4 confidentiality levels",
          "input_schema": {"type": "object", "properties": {"content": {"type": "string"}}, "required": ["content"]}
        },
        {
          "name": "mask_pii",
          "description": "Masks PII entities in a text string",
          "input_schema": {"type": "object", "properties": {"text": {"type": "string"}, "level": {"type": "string", "enum": ["N1", "N2", "N3", "N4"]}}, "required": ["text"]}
        }
      ],
      "status": "stub",
      "repo": "github.com/{org}/savia-shield-mcp",
      "license": "MIT"
    },
    {
      "id": "savia-sdd-mcp",
      "lang": ".NET",
      "capabilities": ["spec_validation", "slicing", "sdd_workflow"],
      "value": "Spec-Driven Development estándar",
      "tools": [
        {
          "name": "spec_validate",
          "description": "Validates a spec against the SDD schema and acceptance criteria",
          "input_schema": {"type": "object", "properties": {"spec_path": {"type": "string"}}, "required": ["spec_path"]}
        },
        {
          "name": "spec_slice",
          "description": "Decomposes a spec into vertical slices with dependencies",
          "input_schema": {"type": "object", "properties": {"spec_path": {"type": "string"}, "max_slices": {"type": "integer", "default": 10}}, "required": ["spec_path"]}
        }
      ],
      "status": "stub",
      "repo": "github.com/{org}/savia-sdd-mcp",
      "license": "MIT"
    },
    {
      "id": "savia-governance-mcp",
      "lang": "TypeScript",
      "capabilities": ["audit", "compliance", "bias_check", "glm"],
      "value": "AI governance",
      "tools": [
        {
          "name": "audit_trail_query",
          "description": "Queries the signed audit trail for governance events",
          "input_schema": {"type": "object", "properties": {"from": {"type": "string"}, "to": {"type": "string"}, "event_type": {"type": "string"}}}
        },
        {
          "name": "compliance_check",
          "description": "Checks a workspace against a compliance framework",
          "input_schema": {"type": "object", "properties": {"framework": {"type": "string", "enum": ["ai-act", "nis2", "dora", "iso9001"]}}, "required": ["framework"]}
        }
      ],
      "status": "stub",
      "repo": "github.com/{org}/savia-governance-mcp",
      "license": "MIT"
    },
    {
      "id": "savia-legal-mcp",
      "lang": "Python",
      "capabilities": ["legalize_es", "compliance_legal_spain", "rgpd"],
      "value": "Compliance legal España",
      "tools": [
        {
          "name": "legal_query",
          "description": "Queries legalize-es for Spanish legal compliance checks",
          "input_schema": {"type": "object", "properties": {"question": {"type": "string"}, "domain": {"type": "string", "enum": ["rgpd", "lssi", "ai-act-spain", "labor"]}}, "required": ["question"]}
        },
        {
          "name": "legal_summarize",
          "description": "Summarizes a legal document in plain language",
          "input_schema": {"type": "object", "properties": {"document": {"type": "string"}}, "required": ["document"]}
        }
      ],
      "status": "stub",
      "repo": "github.com/{org}/savia-legal-mcp",
      "license": "MIT"
    }
  ]
}
EOF

echo "catalog.json generado en $OUTPUT_DIR/catalog.json"
SERVER_COUNT=$(grep -c '"id"' "$OUTPUT_DIR/catalog.json" || echo 0)
echo "Total servers: $SERVER_COUNT"
