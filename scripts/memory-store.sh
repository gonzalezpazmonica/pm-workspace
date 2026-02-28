#!/bin/bash
# memoria-store.sh - JSONL-based persistent memory store for pm-workspace
set -euo pipefail

STORE_FILE="${PROJECT_ROOT:-.}/output/.memory-store.jsonl"
mkdir -p "$(dirname "$STORE_FILE")"

redact_private() { sed 's/<private>.*<\/private>/[REDACTED]/g'; }
hash_content() { echo -n "$1" | sha256sum | cut -d' ' -f1; }
iso8601_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

cmd_save() {
    local type= title= content= topic_key= project= rev=1
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type) type="$2"; shift 2 ;;
            --title) title="$2"; shift 2 ;;
            --content) content="$2"; shift 2 ;;
            --topic) topic_key="$2"; shift 2 ;;
            --project) project="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    [[ -z "$type" || -z "$title" || -z "$content" ]] && { echo "Error: --type, --title, --content requeridos"; exit 1; }

    content=$(echo "$content" | redact_private | head -c 2000)
    local hash=$(hash_content "$content") now=$(iso8601_now)

    # UPSERT por topic_key
    if [[ -n "$topic_key" && -f "$STORE_FILE" ]]; then
        local old_line=$(grep "\"topic_key\":\"$topic_key\"" "$STORE_FILE" 2>/dev/null | tail -1 || true)
        if [[ -n "$old_line" ]]; then
            rev=$(($(echo "$old_line" | grep -o '"rev":[0-9]*' | cut -d: -f2) + 1))
            grep -v "\"topic_key\":\"$topic_key\"" "$STORE_FILE" > "$STORE_FILE.tmp" || true
            mv "$STORE_FILE.tmp" "$STORE_FILE"
        fi
    fi

    # Dedup (últimos 15 min)
    [[ -f "$STORE_FILE" ]] && grep "\"hash\":\"$hash\"" "$STORE_FILE" 2>/dev/null | while IFS= read -r line; do
        local ts=$(echo "$line" | grep -o '"ts":"[^"]*"' | cut -d'"' -f4)
        [[ $(date -d "$ts" +%s 2>/dev/null || echo 0) -gt $(date -u -d '15 minutes ago' +%s) ]] && { echo "⊘ Duplicado omitido"; exit 0; }
    done

    echo "{\"ts\":\"$now\",\"type\":\"$type\",\"title\":\"$title\",\"content\":\"$content\",\"topic_key\":\"${topic_key:-null}\",\"project\":\"${project:-null}\",\"hash\":\"$hash\",\"rev\":$rev}" >> "$STORE_FILE"
    echo "✓ Guardado: $title (tipo: $type)"
}

cmd_search() {
    [[ ! -f "$STORE_FILE" ]] && { echo "No hay memory store"; return; }
    grep -i "$1" "$STORE_FILE" 2>/dev/null | while IFS= read -r line; do
        local ts=$(echo "$line" | grep -o '"ts":"[^"]*"' | cut -d'"' -f4)
        local type=$(echo "$line" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
        local title=$(echo "$line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
        local content=$(echo "$line" | grep -o '"content":"[^"]*"' | sed 's/"content":"//' | sed 's/"$//')
        echo "  [$ts] $type: $title" && echo "       → ${content:0:80}..."
    done
}

cmd_context() {
    [[ ! -f "$STORE_FILE" ]] && return
    local limit=20 project=
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit) limit="$2"; shift 2 ;;
            --project) project="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    echo "## 🧠 Memoria Persistente" && echo ""
    if [[ -n "$project" ]]; then
        grep "\"project\":\"$project\"" "$STORE_FILE" 2>/dev/null | tac | head -n "$limit"
    else
        tac "$STORE_FILE" | head -n "$limit"
    fi | while IFS= read -r line; do
        local ts=$(echo "$line" | grep -o '"ts":"[^"]*"' | cut -d'"' -f4 | cut -d'T' -f1)
        local type=$(echo "$line" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
        local title=$(echo "$line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
        echo "- [$ts] ($type) $title"
    done
}

cmd_stats() {
    [[ ! -f "$STORE_FILE" ]] && { echo "No hay memory store"; return; }
    echo "📊 Estadísticas — Total: $(wc -l < "$STORE_FILE") entradas" && echo ""
    echo "Por tipo:" && cut -d'"' -f4 "$STORE_FILE" | grep -E '^(decision|bug|pattern|convention|discovery)$' | \
        sort | uniq -c | sort -rn | awk '{ printf "  %s: %d\n", $2, $1 }'
}

case "${1:-help}" in
    save) shift; cmd_save "$@" ;;
    search) cmd_search "$2" ;;
    context) shift; cmd_context "$@" ;;
    stats) cmd_stats ;;
    *) cat <<'EOF'
Uso: memory-store.sh <cmd> [opciones]
  save --type {decision|bug|pattern|convention|discovery} \
       --title "..." --content "..." [--topic tema] [--project proyecto]
  search "query" | context [--project X] [--limit 20] | stats
EOF
        ;;
esac
