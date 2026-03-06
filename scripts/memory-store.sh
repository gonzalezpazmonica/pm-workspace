#!/bin/bash
# memory-store.sh - JSONL persistent memory store for pm-workspace
set -euo pipefail
STORE_FILE="${PROJECT_ROOT:-.}/output/.memory-store.jsonl"
mkdir -p "$(dirname "$STORE_FILE")"
redact_private() { sed 's/<private>.*<\/private>/[REDACTED]/g'; }
hash_content() { echo -n "$1" | sha256sum | cut -d' ' -f1; }
iso8601_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

cmd_save() {
    local type= title= content= concepts= topic_key= project= rev=1
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type) type="$2"; shift 2 ;;
            --title) title="$2"; shift 2 ;;
            --content) content="$2"; shift 2 ;;
            --concepts) concepts="$2"; shift 2 ;;
            --topic) topic_key="$2"; shift 2 ;;
            --project) project="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    [[ -z "$type" || -z "$title" || -z "$content" ]] && { echo "Error: --type, --title, --content requeridos"; exit 1; }

    content=$(echo "$content" | redact_private | head -c 2000)
    content="${content//$'\n'/\\n}"
    content="${content//$'\r'/\\r}"
    content="${content//$'\t'/\\t}"
    local tokens_est=$((${#content} / 4))
    local hash=$(hash_content "$content") now=$(iso8601_now)

    # Parse concepts into JSON array
    local concepts_json="[]"
    if [[ -n "$concepts" ]]; then
        concepts_json="["
        IFS=',' read -ra CPTS <<< "$concepts"
        for i in "${!CPTS[@]}"; do
            concepts_json="$concepts_json\"${CPTS[$i]// /}\""
            [[ $i -lt $((${#CPTS[@]} - 1)) ]] && concepts_json="$concepts_json,"
        done
        concepts_json="$concepts_json]"
    fi

    # UPSERT por topic_key
    if [[ -n "$topic_key" && -f "$STORE_FILE" ]]; then
        local old_line=$(grep -F "\"topic_key\":\"$topic_key\"" "$STORE_FILE" 2>/dev/null | tail -1 || true)
        if [[ -n "$old_line" ]]; then
            rev=$(($(echo "$old_line" | grep -o '"rev":[0-9]*' | cut -d: -f2) + 1))
            grep -v "\"topic_key\":\"$topic_key\"" "$STORE_FILE" > "$STORE_FILE.tmp" || true
            mv "$STORE_FILE.tmp" "$STORE_FILE"
        fi
    fi

    # Dedup (últimos 15 min) — skip if same hash exists recently
    if [[ -f "$STORE_FILE" ]] && grep -q "\"hash\":\"$hash\"" "$STORE_FILE" 2>/dev/null; then
        local recent_ts=$(grep "\"hash\":\"$hash\"" "$STORE_FILE" | tail -1 | grep -o '"ts":"[^"]*"' | cut -d'"' -f4)
        local recent_epoch=$(date -d "$recent_ts" +%s 2>/dev/null || echo 0)
        local cutoff=$(date -u -d '15 minutes ago' +%s 2>/dev/null || echo 0)
        if [[ $recent_epoch -gt $cutoff ]]; then echo "⊘ Duplicado omitido"; return 0; fi
    fi
    echo "{\"ts\":\"$now\",\"type\":\"$type\",\"title\":\"$title\",\"content\":\"$content\",\"concepts\":$concepts_json,\"tokens_est\":$tokens_est,\"topic_key\":\"${topic_key:-null}\",\"project\":\"${project:-null}\",\"hash\":\"$hash\",\"rev\":$rev}" >> "$STORE_FILE"
    echo "✓ Guardado: $title (tipo: $type)"
}

cmd_search() {
    [[ ! -f "$STORE_FILE" ]] && { echo "No hay memory store"; return; }
    local query= type_filter= since_date=
    while [[ $# -gt 0 ]]; do case "$1" in --type) type_filter="$2"; shift 2;; --since) since_date="$2"; shift 2;; *) query="$1"; shift;; esac; done
    [[ -z "$query" ]] && { echo "Uso: search \"query\" [--type tipo] [--since YYYY-MM-DD]"; return; }
    declare -A scored_entries
    while IFS= read -r line; do
        local ts=$(echo "$line" | grep -o '"ts":"[^"]*"' | cut -d'"' -f4 | cut -d'T' -f1)
        [[ -n "$since_date" && "$ts" < "$since_date" ]] && continue
        local type=$(echo "$line" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
        [[ -n "$type_filter" && "$type" != "$type_filter" ]] && continue
        local score=0 title=$(echo "$line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
        [[ "$title" =~ $query ]] && score=$((score+3))
        [[ "$(echo "$line" | grep -o '"content":"[^"]*"')" =~ $query ]] && score=$((score+1))
        [[ "$(echo "$line" | grep -o '"concepts":\[.*\]')" =~ $query ]] && score=$((score+2))
        [[ $score -gt 0 ]] && scored_entries["$score|$ts|$title"]="$line"
    done < "$STORE_FILE"
    local count=0
    for key in $(printf '%s\n' "${!scored_entries[@]}" | sort -rn | head -10); do
        local type=$(echo "${scored_entries[$key]}" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
        echo "  [$(echo "$key" | cut -d'|' -f2)] ($type) $(echo "$key" | cut -d'|' -f3-) [score:$(echo "$key" | cut -d'|' -f1)]"
        count=$((count+1))
    done
    [[ $count -eq 0 ]] && echo "No se encontraron resultados" || true
}

cmd_context() {
    [[ ! -f "$STORE_FILE" ]] && return
    local limit=20 project=
    while [[ $# -gt 0 ]]; do case "$1" in --limit) limit="$2"; shift 2;; --project) project="$2"; shift 2;; *) shift;; esac; done
    echo "## 🧠 Memoria Persistente" && echo ""
    local src; [[ -n "$project" ]] && src=$(grep "\"project\":\"$project\"" "$STORE_FILE" 2>/dev/null | tac | head -n "$limit") || src=$(tac "$STORE_FILE" | head -n "$limit")
    echo "$src" | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local ts=$(echo "$line" | grep -o '"ts":"[^"]*"' | cut -d'"' -f4 | cut -d'T' -f1)
        local type=$(echo "$line" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
        local title=$(echo "$line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
        echo "- [$ts] ($type) $title"
    done
}

cmd_stats() {
    [[ ! -f "$STORE_FILE" ]] && { echo "No hay memory store"; return; }
    echo "📊 Estadísticas — Total: $(wc -l < "$STORE_FILE") entradas"
    echo "Por tipo:" && grep -o '"type":"[^"]*"' "$STORE_FILE" | cut -d'"' -f4 | \
        sort | uniq -c | sort -rn | awk '{ printf "  %s: %d\n", $2, $1 }'
    echo "Por concepto:" && grep -o '"concepts":\[[^]]*\]' "$STORE_FILE" | sed 's/.*\[//;s/\].*//' | \
        tr ',' '\n' | tr -d '"' | sed '/^$/d' | sort | uniq -c | sort -rn | head -5 | \
        awk '{ printf "  %s: %d\n", $2, $1 }'
}

cmd_entity() {
    local action="${1:-list}" query= etype= proj=
    shift 2>/dev/null || true
    while [[ $# -gt 0 ]]; do case "$1" in --type) etype="$2"; shift 2;; --project) proj="$2"; shift 2;; *) query="$1"; shift;; esac; done
    [[ ! -f "$STORE_FILE" ]] && { echo "No hay entidades registradas"; return; }
    local filter='grep "\"type\":\"entity\"" "$STORE_FILE"'
    if [[ "$action" == "list" ]]; then
        echo "## 🧩 Entidades Registradas"
        grep '"type":"entity"' "$STORE_FILE" 2>/dev/null | while IFS= read -r line; do
            local t=$(echo "$line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
            local c=$(echo "$line" | grep -o '"concepts":\[[^]]*\]' | sed 's/.*\[//;s/\].*//' | tr -d '"')
            local p=$(echo "$line" | grep -o '"project":"[^"]*"' | cut -d'"' -f4)
            [[ -n "$etype" && "$c" != *"$etype"* ]] && continue
            [[ -n "$proj" && "$p" != "$proj" ]] && continue
            echo "  - $t ($c) — proyecto: $p"
        done
    elif [[ "$action" == "find" ]]; then
        [[ -z "$query" ]] && { echo "Uso: entity find {nombre}"; return; }
        grep '"type":"entity"' "$STORE_FILE" 2>/dev/null | grep -i "$query" | while IFS= read -r line; do
            local t=$(echo "$line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
            local c=$(echo "$line" | grep -o '"content":"[^"]*"' | sed 's/"content":"//' | sed 's/"$//')
            local ts=$(echo "$line" | grep -o '"ts":"[^"]*"' | cut -d'"' -f4 | cut -d'T' -f1)
            echo "🧩 $t — $ts: $c"
        done
    else echo "Uso: entity {list|find} [nombre] [--type tipo] [--project proj]"; fi
}

case "${1:-help}" in
    save) shift; cmd_save "$@" ;;
    search) shift; cmd_search "$@" ;;
    context) shift; cmd_context "$@" ;;
    stats) cmd_stats ;;
    entity) shift; cmd_entity "$@" ;;
    *) echo "Uso: memory-store.sh {save|search|context|stats|entity} [opciones]" ;;
esac
