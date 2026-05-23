#!/usr/bin/env bash
# SPEC-141 · savia-memory MCP stdio wrapper
# Implements MCP protocol (JSON-RPC 2.0 over stdio) for savia-memory tools.
#
# Exposed tools:
#   - memory_recall(query: string, limit?: int)
#   - memory_save(content: string, tags?: string[])
#   - memory_stats()
#
# Minimal implementation: handles initialize, tools/list, tools/call.
# Delegates to scripts/memory-store.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY_STORE="$SCRIPT_DIR/memory-store.sh"

if [[ ! -x "$MEMORY_STORE" ]]; then
  echo '{"jsonrpc":"2.0","error":{"code":-32603,"message":"memory-store.sh not executable"}}' >&2
  exit 1
fi

# JSON-RPC response helper
respond() {
  local id="$1" result="$2"
  printf '{"jsonrpc":"2.0","id":%s,"result":%s}\n' "$id" "$result"
}

respond_error() {
  local id="$1" code="$2" msg="$3"
  printf '{"jsonrpc":"2.0","id":%s,"error":{"code":%s,"message":"%s"}}\n' "$id" "$code" "$msg"
}

TOOLS_LIST='[
  {"name":"memory_recall","description":"Recall memories matching query","inputSchema":{"type":"object","properties":{"query":{"type":"string"},"limit":{"type":"integer","default":5}},"required":["query"]}},
  {"name":"memory_save","description":"Save a memory entry","inputSchema":{"type":"object","properties":{"content":{"type":"string"},"tags":{"type":"array","items":{"type":"string"}}},"required":["content"]}},
  {"name":"memory_stats","description":"Return memory store statistics","inputSchema":{"type":"object","properties":{}}}
]'

handle_tools_call() {
  local id="$1" tool="$2" args="$3"
  local output=""
  case "$tool" in
    memory_recall)
      local query limit
      query=$(printf '%s' "$args" | jq -r '.query // ""')
      limit=$(printf '%s' "$args" | jq -r '.limit // 5')
      output=$("$MEMORY_STORE" recall "$query" 2>&1 | head -n "$limit" || true)
      ;;
    memory_save)
      local content
      content=$(printf '%s' "$args" | jq -r '.content // ""')
      output=$("$MEMORY_STORE" save "$content" 2>&1 || true)
      ;;
    memory_stats)
      output=$("$MEMORY_STORE" stats 2>&1 || true)
      ;;
    *)
      respond_error "$id" -32601 "Unknown tool: $tool"
      return
      ;;
  esac
  local content_json
  content_json=$(printf '%s' "$output" | jq -Rs '{content:[{type:"text",text:.}]}')
  respond "$id" "$content_json"
}

# Main loop: read JSON-RPC requests from stdin
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  method=$(printf '%s' "$line" | jq -r '.method // ""')
  id=$(printf '%s' "$line" | jq -r '.id // 0')

  case "$method" in
    initialize)
      respond "$id" '{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"savia-memory","version":"1.0.0"}}'
      ;;
    tools/list)
      respond "$id" "$(printf '{"tools":%s}' "$TOOLS_LIST")"
      ;;
    tools/call)
      tool=$(printf '%s' "$line" | jq -r '.params.name // ""')
      args=$(printf '%s' "$line" | jq -c '.params.arguments // {}')
      handle_tools_call "$id" "$tool" "$args"
      ;;
    notifications/initialized|notifications/*)
      : # silent ack
      ;;
    *)
      respond_error "$id" -32601 "Method not found: $method"
      ;;
  esac
done
