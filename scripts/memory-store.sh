#!/bin/bash
# memory-store.sh — JSONL persistent memory store for pm-workspace
# Dispatcher + shared utils. Logic in memory-save.sh and memory-search.sh.
# Inspired by Engram (Gentleman-Programming/engram) observation model.
set -euo pipefail

# Guard: $HOME must be defined — /tmp fallback is PROHIBITED
if [[ -z "${HOME:-}" ]]; then
  echo "ERROR: \$HOME no definido — no se puede escribir memoria. Configura \$HOME antes de invocar memory-store.sh" >&2
  exit 1
fi

STORE_FILE="${PROJECT_ROOT:-.}/output/.memory-store.jsonl"
mkdir -p "$(dirname "$STORE_FILE")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Embedding server lazy-start ---
# Ensures the in-process embedding server is running before vector/hybrid search.
# Avoids 15-30s cold-start on first recall. Skipped in grep-only mode.
SAVIA_EMBED_PORT="${SAVIA_EMBED_PORT:-7331}"
SAVIA_EMBED_URL="${SAVIA_EMBED_URL:-http://127.0.0.1:$SAVIA_EMBED_PORT}"

_ensure_embed_server() {
    [[ "${SAVIA_TEST_MODE:-false}" == "true" ]] && return 0
    command -v python3 &>/dev/null || return 0
    # Check if already running
    if python3 -c "import urllib.request; urllib.request.urlopen('$SAVIA_EMBED_URL/health', timeout=1)" &>/dev/null 2>&1; then
        return 0
    fi
    # Not running — launch in background
    local server_script="$SCRIPT_DIR/embedding-server.py"
    [[ -f "$server_script" ]] || return 0
    local os_type
    os_type="$(uname -s 2>/dev/null || echo Windows)"
    case "$os_type" in
        MINGW*|MSYS*|CYGWIN*|Windows*)
            cmd.exe /c "start /b python3 \"$server_script\"" &>/dev/null 2>&1 || true ;;
        *)
            nohup python3 "$server_script" >/dev/null 2>&1 & ;;
    esac
    # Brief wait for model load (non-blocking — search proceeds with fallback if not ready)
    sleep 2
}
export SAVIA_EMBED_URL

# --- Shared utils ---
redact_private() { sed 's/<private>.*<\/private>/[REDACTED]/g'; }
hash_content() { echo -n "$1" | sha256sum | cut -d' ' -f1; }
iso8601_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Update the canonical memory index at ~/.savia-memory/auto/MEMORY.md
# Called after each successful JSONL save to keep the index in sync.
#
# Dedup contract: if topic_key already exists in the ENTRIES block, the line
# is REPLACED in-place (preserving order). If absent, a new line is INSERTED
# at the top of the block. This prevents the unbounded duplication that
# previously inflated MEMORY.md from cap 200 to 730+ lines (SE-073/SPEC-142).
#
# Soft cap enforcement: if the resulting block exceeds MEMORY_INDEX_SOFT_CAP
# entries (default 200), the oldest entries (bottom of block) are trimmed.
_update_memory_index() {
    local topic_key="$1" title="$2" type="$3"
    local idx_file="${HOME}/.savia-memory/auto/MEMORY.md"
    [[ ! -f "$idx_file" ]] && return 0
    [[ -z "$topic_key" || "$topic_key" == "null" ]] && return 0

    local entry="- ${type}: ${title} [${topic_key}]"
    entry="${entry:0:150}"
    local marker="[${topic_key}]"
    local soft_cap="${MEMORY_INDEX_SOFT_CAP:-200}"

    local tmp; tmp=$(mktemp)
    local in_entries=false replaced=false
    # Pass 1 — copy file replacing the existing line for topic_key (if any)
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "<!-- ENTRIES_START -->" ]]; then
            in_entries=true; echo "$line" >> "$tmp"; continue
        fi
        if [[ "$line" == "<!-- ENTRIES_END -->" ]]; then
            in_entries=false; echo "$line" >> "$tmp"; continue
        fi
        if $in_entries && [[ "$line" == *"$marker"* ]]; then
            # Replace existing entry for this topic_key (idempotent update)
            echo "$entry" >> "$tmp"; replaced=true; continue
        fi
        echo "$line" >> "$tmp"
    done < "$idx_file"

    # Pass 2 — if no replacement happened, insert new entry at top of block
    if ! $replaced; then
        local tmp2; tmp2=$(mktemp)
        local injected=false
        while IFS= read -r line || [[ -n "$line" ]]; do
            echo "$line" >> "$tmp2"
            if ! $injected && [[ "$line" == "<!-- ENTRIES_START -->" ]]; then
                echo "$entry" >> "$tmp2"; injected=true
            fi
        done < "$tmp"
        mv "$tmp2" "$tmp"
    fi

    # Pass 3 — soft cap: trim oldest entries (bottom of block) if exceeded
    local entry_count
    entry_count=$(awk '/^<!-- ENTRIES_START -->$/{flag=1; next} /^<!-- ENTRIES_END -->$/{flag=0} flag && /^- /' "$tmp" | wc -l)
    if (( entry_count > soft_cap )); then
        local tmp3; tmp3=$(mktemp)
        python3 - "$tmp" "$tmp3" "$soft_cap" <<'PY' 2>/dev/null || cp "$tmp" "$tmp3"
import sys
src, dst, cap = sys.argv[1], sys.argv[2], int(sys.argv[3])
with open(src, 'r', encoding='utf-8') as f:
    lines = f.readlines()
out = []
in_block = False
block = []
for ln in lines:
    if ln.strip() == '<!-- ENTRIES_START -->':
        in_block = True
        out.append(ln)
        continue
    if ln.strip() == '<!-- ENTRIES_END -->':
        in_block = False
        # keep only first `cap` entries from block (top = newest)
        kept = [b for b in block if b.lstrip().startswith('- ')][:cap]
        out.extend(kept)
        out.append(ln)
        block = []
        continue
    if in_block:
        block.append(ln)
    else:
        out.append(ln)
with open(dst, 'w', encoding='utf-8') as f:
    f.writelines(out)
PY
        mv "$tmp3" "$tmp"
    fi

    mv "$tmp" "$idx_file"
}

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

cmd_doctor() {
    local level=0 warn=""
    local has_st=false has_idx=false
    python3 -c "import sentence_transformers" 2>/dev/null && has_st=true
    python3 -c "import hnswlib" 2>/dev/null || python3 -c "import faiss" 2>/dev/null && has_idx=true
    $has_st && $has_idx && level=2 || { $has_st && level=1; }

    echo "=== memory-store doctor ==="
    echo "Level: $level (0=grep, 1=partial, 2=vector+hybrid)"
    $has_st && echo "  sentence_transformers: OK" || echo "  sentence_transformers: NOT INSTALLED"
    $has_idx && echo "  vector backend (hnswlib/faiss): OK" || echo "  vector backend (hnswlib/faiss): NOT INSTALLED"

    local idx_faiss="${STORE_FILE%.jsonl}-index.faiss"
    local idx_hnsw="${STORE_FILE%.jsonl}-index.idx"
    if [[ -f "$idx_faiss" || -f "$idx_hnsw" ]]; then
        local idx="$idx_faiss"; [[ -f "$idx_hnsw" ]] && idx="$idx_hnsw"
        if [[ "$STORE_FILE" -nt "$idx" ]]; then
            echo "  index: STALE"
            echo "  fix:   bash scripts/memory-store.sh rebuild-index"
        else
            echo "  index: fresh"
        fi
    else
        echo "  index: ABSENT"
        echo "  fix:   bash scripts/memory-store.sh rebuild-index"
    fi

    if [[ $level -lt 2 ]]; then
        echo ""
        echo "[WARN] Vector search DISABLED — running grep-only"
        echo "  fix: pip install -r scripts/requirements-memory.txt"
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
    local t="${1:-}" ti="${2:-}"    [[ -z "$t" || -z "$ti" ]] && { echo "Uso: suggest-topic {type} {title}"; return 1; }
    suggest_topic_key "$t" "$ti"
}

# Skip dispatcher if sourced (allows tests to load functions without executing)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 0 2>/dev/null || true
fi

case "${1:-help}" in
    save) shift; cmd_save "$@" ;;
    search|recall) shift; _ensure_embed_server; cmd_search "$@" ;;
    context) shift; cmd_context "$@" ;;
    stats) cmd_stats ;;
    prune) cmd_prune ;;
    entity) shift; cmd_entity "$@" ;;
    suggest-topic) shift; cmd_suggest_topic "$@" ;;
    session-summary) shift; cmd_session_summary "$@" ;;
    doctor) cmd_doctor ;;
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
  session-summary, rebuild-index, index-status, benchmark, doctor,
  build-graph, graph-search, graph-status, graph-entities

Save: --type TYPE --title TITLE [--content TEXT] [--what/--why/--where/--learned]
  [--topic KEY] [--concepts CSV] [--project NAME] [--expires DAYS]

Search: "query" [--type TYPE] [--since DATE] [--mode grep|vector|auto]
  [--include-expired]

Vector index auto-rebuilds on JSONL changes (if deps installed).
Install: pip install sentence-transformers hnswlib
USAGE
    ;;
    *) echo "Usage: memory-store.sh {save|search|context|stats|entity|suggest-topic|session-summary|rebuild-index|index-status|benchmark|doctor|help}" >&2
       exit 1
    ;;
esac
