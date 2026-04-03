#!/bin/bash
# memory-store.sh — JSONL persistent memory store for pm-workspace
# Dispatcher + shared utils. Logic in memory-save.sh and memory-search.sh.
# Inspired by Engram (Gentleman-Programming/engram) observation model.
set -euo pipefail
STORE_FILE="${PROJECT_ROOT:-.}/output/.memory-store.jsonl"
mkdir -p "$(dirname "$STORE_FILE")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Shared utils ---
redact_private() { sed 's/<private>.*<\/private>/[REDACTED]/g'; }
hash_content() { echo -n "$1" | sha256sum | cut -d' ' -f1; }
iso8601_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

_maybe_rebuild_index() {
    [[ "${SAVIA_TEST_MODE:-false}" == "true" ]] && return 0
    command -v python3 &>/dev/null || return 0
    python3 -c "import sentence_transformers; import faiss" 2>/dev/null \
      || python3 -c "import sentence_transformers; import hnswlib" 2>/dev/null \
      || return 0
    local idx_faiss="${STORE_FILE%.jsonl}-index.faiss"
    local idx_hnsw="${STORE_FILE%.jsonl}-index.idx"
    local idx="$idx_faiss"
    [[ -f "$idx_hnsw" ]] && idx="$idx_hnsw"
    if [[ ! -f "$idx_faiss" && ! -f "$idx_hnsw" ]] || [[ "$STORE_FILE" -nt "$idx" ]]; then
        python3 "$SCRIPT_DIR/memory-vector.py" rebuild --store "$STORE_FILE" >/dev/null 2>&1 &
        echo "(vector index rebuilding in background)" >&2
    fi
}

suggest_topic_key() {
    local type="$1" title="$2"
    local slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | cut -c1-40)
    case "$type" in
        decision) echo "decision/$slug" ;; bug) echo "bug/$slug" ;;
        pattern) echo "pattern/$slug" ;; convention) echo "convention/$slug" ;;
        discovery) echo "discovery/$slug" ;; architecture) echo "architecture/$slug" ;;
        config) echo "config/$slug" ;; entity) echo "entity/$slug" ;;
        *) echo "$type/$slug" ;;
    esac
}

# --- Load modules ---
source "$SCRIPT_DIR/memory-save.sh"
source "$SCRIPT_DIR/memory-search.sh"

# --- Dispatcher ---
cmd_suggest_topic() {
    local t="${1:-}" ti="${2:-}"
    [[ -z "$t" || -z "$ti" ]] && { echo "Uso: suggest-topic {type} {title}"; return 1; }
    suggest_topic_key "$t" "$ti"
}

case "${1:-help}" in
    save) shift; cmd_save "$@" ;;
    search) shift; cmd_search "$@" ;;
    context) shift; cmd_context "$@" ;;
    stats) cmd_stats ;;
    entity) shift; cmd_entity "$@" ;;
    suggest-topic) shift; cmd_suggest_topic "$@" ;;
    session-summary) shift; cmd_session_summary "$@" ;;
    rebuild-index) python3 "$SCRIPT_DIR/memory-vector.py" rebuild --store "$STORE_FILE" ;;
    index-status) python3 "$SCRIPT_DIR/memory-vector.py" status --store "$STORE_FILE" ;;
    benchmark) python3 "$SCRIPT_DIR/memory-vector.py" benchmark --store "$STORE_FILE" ;;
    build-graph) python3 "$SCRIPT_DIR/memory-graph.py" build --store "$STORE_FILE" ;;
    graph-search) shift; python3 "$SCRIPT_DIR/memory-graph.py" search "$@" --store "$STORE_FILE" ;;
    graph-status) python3 "$SCRIPT_DIR/memory-graph.py" status --store "$STORE_FILE" ;;
    graph-entities) shift; python3 "$SCRIPT_DIR/memory-graph.py" entities "$@" --store "$STORE_FILE" ;;
    help) cat <<'USAGE'
memory-store.sh {command} [options]

Commands: save, search, context, stats, entity, suggest-topic,
  session-summary, rebuild-index, index-status, benchmark,
  build-graph, graph-search, graph-status, graph-entities

Save: --type TYPE --title TITLE [--content TEXT] [--what/--why/--where/--learned]
  [--topic KEY] [--concepts CSV] [--project NAME] [--expires DAYS]

Search: "query" [--type TYPE] [--since DATE] [--mode grep|vector|auto]
  [--include-expired]

Vector index auto-rebuilds on JSONL changes (if deps installed).
Install: pip install sentence-transformers hnswlib
USAGE
    ;;
    *) echo "Usage: memory-store.sh {save|search|context|stats|entity|suggest-topic|session-summary|rebuild-index|index-status|benchmark|help}" >&2
       exit 1
    ;;
esac
