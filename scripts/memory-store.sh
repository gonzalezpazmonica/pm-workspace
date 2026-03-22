#!/bin/bash
# memory-store.sh - JSONL persistent memory store for pm-workspace
# Inspired by Engram (Gentleman-Programming/engram) observation model
set -euo pipefail
STORE_FILE="${PROJECT_ROOT:-.}/output/.memory-store.jsonl"
mkdir -p "$(dirname "$STORE_FILE")"
redact_private() { sed 's/<private>.*<\/private>/[REDACTED]/g'; }
hash_content() { echo -n "$1" | sha256sum | cut -d' ' -f1; }
iso8601_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Topic key families — consistent prefixes (inspired by Engram)
suggest_topic_key() {
    local type="$1" title="$2"
    local slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | cut -c1-40)
    case "$type" in
        decision)      echo "decision/$slug" ;;
        bug)           echo "bug/$slug" ;;
        pattern)       echo "pattern/$slug" ;;
        convention)    echo "convention/$slug" ;;
        discovery)     echo "discovery/$slug" ;;
        architecture)  echo "architecture/$slug" ;;
        config)        echo "config/$slug" ;;
        entity)        echo "entity/$slug" ;;
        *)             echo "$type/$slug" ;;
    esac
}

cmd_save() {
    local type= title= content= concepts= topic_key= project= rev=1
    local what= why= where= learned=
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type) type="$2"; shift 2 ;;
            --title) title="$2"; shift 2 ;;
            --content) content="$2"; shift 2 ;;
            --concepts) concepts="$2"; shift 2 ;;
            --topic) topic_key="$2"; shift 2 ;;
            --project) project="$2"; shift 2 ;;
            --what) what="$2"; shift 2 ;;
            --why) why="$2"; shift 2 ;;
            --where) where="$2"; shift 2 ;;
            --learned) learned="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    [[ -z "$type" || -z "$title" ]] && { echo "Error: --type, --title requeridos"; exit 1; }

    # Build structured content from W/W/W/L fields if provided
    if [[ -n "$what" || -n "$why" || -n "$where" || -n "$learned" ]]; then
        local structured=""
        [[ -n "$what" ]] && structured="What: $what"
        [[ -n "$why" ]] && structured="$structured | Why: $why"
        [[ -n "$where" ]] && structured="$structured | Where: $where"
        [[ -n "$learned" ]] && structured="$structured | Learned: $learned"
        # Append to content or use as content
        if [[ -n "$content" ]]; then
            content="$content | $structured"
        else
            content="$structured"
        fi
    fi
    [[ -z "$content" ]] && { echo "Error: --content or --what required"; exit 1; }

    content=$(echo "$content" | redact_private | head -c 2000)
    content="${content//$'\n'/\\n}"
    content="${content//$'\r'/\\r}"
    content="${content//$'\t'/\\t}"
    local tokens_est=$((${#content} / 4))
    local hash=$(hash_content "$content") now=$(iso8601_now)

    # Auto-suggest topic_key if not provided (Engram family pattern)
    if [[ -z "$topic_key" ]]; then
        topic_key=$(suggest_topic_key "$type" "$title")
    fi

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

    # UPSERT por topic_key (atomic write with mv)
    if [[ -n "$topic_key" && "$topic_key" != "null" && -f "$STORE_FILE" ]]; then
        local old_line=$(grep -F "\"topic_key\":\"$topic_key\"" "$STORE_FILE" 2>/dev/null | tail -1 || true)
        if [[ -n "$old_line" ]]; then
            rev=$(($(echo "$old_line" | grep -o '"rev":[0-9]*' | cut -d: -f2) + 1))
            local temp_file=$(mktemp)
            grep -vF "\"topic_key\":\"$topic_key\"" "$STORE_FILE" > "$temp_file" || true
            mv "$temp_file" "$STORE_FILE"
        fi
    fi

    # Dedup (ultimos 15 min) — skip if same hash exists recently
    if [[ -f "$STORE_FILE" ]] && grep -qF "\"hash\":\"$hash\"" "$STORE_FILE" 2>/dev/null; then
        local recent_ts=$(grep -F "\"hash\":\"$hash\"" "$STORE_FILE" | tail -1 | grep -o '"ts":"[^"]*"' | cut -d'"' -f4)
        local recent_epoch=$(date -d "$recent_ts" +%s 2>/dev/null || echo 0)
        local cutoff=$(date -u -d '15 minutes ago' +%s 2>/dev/null || echo 0)
        if [[ $recent_epoch -gt $cutoff ]]; then echo "⊘ Duplicado omitido"; return 0; fi
    fi
    echo "{\"ts\":\"$now\",\"type\":\"$type\",\"title\":\"$title\",\"content\":\"$content\",\"concepts\":$concepts_json,\"tokens_est\":$tokens_est,\"topic_key\":\"${topic_key}\",\"project\":\"${project:-null}\",\"hash\":\"$hash\",\"rev\":$rev}" >> "$STORE_FILE"
    echo "✓ Guardado: $title (topic: $topic_key, rev: $rev)"
}

cmd_search() {
    [[ ! -f "$STORE_FILE" ]] && { echo "No hay memory store"; return; }
    local query= type_filter= since_date=
    while [[ $# -gt 0 ]]; do case "$1" in --type) type_filter="$2"; shift 2;; --since) since_date="$2"; shift 2;; *) query="$1"; shift;; esac; done
    [[ -z "$query" ]] && { echo "Uso: search \"query\" [--type tipo] [--since YYYY-MM-DD]"; return; }
    # Use temp file for scored results (avoids bash 4 associative array issues in subshells)
    local tmp_results=$(mktemp)
    trap "rm -f '$tmp_results'" RETURN
    while IFS= read -r line; do
        local ts type title topic score=0
        ts=$(echo "$line" | grep -o '"ts":"[^"]*"' | cut -d'"' -f4 | cut -d'T' -f1)
        [[ -n "$since_date" && "$ts" < "$since_date" ]] && continue
        type=$(echo "$line" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
        [[ -n "$type_filter" && "$type" != "$type_filter" ]] && continue
        title=$(echo "$line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
        topic=$(echo "$line" | grep -o '"topic_key":"[^"]*"' | cut -d'"' -f4)
        local rev=$(echo "$line" | grep -o '"rev":[0-9]*' | cut -d: -f2)
        echo "$title" | grep -qi "$query" 2>/dev/null && score=$((score+3)) || true
        echo "$line" | grep -qi "$query" 2>/dev/null && score=$((score+1)) || true
        echo "$topic" | grep -qi "$query" 2>/dev/null && score=$((score+2)) || true
        [[ $score -gt 0 ]] && printf '%03d\t%s\t%s\t%s\t%s\t%s\n' "$score" "$ts" "$type" "$title" "$topic" "$rev" >> "$tmp_results"
    done < "$STORE_FILE"
    if [[ -s "$tmp_results" ]]; then
        sort -rn "$tmp_results" | head -10 | while IFS=$'\t' read -r score ts type title topic rev; do
            echo "  [$ts] ($type) $title [topic:$topic rev:$rev score:$((10#$score))]"
        done
    else
        echo "No se encontraron resultados"
    fi
}

cmd_context() {
    [[ ! -f "$STORE_FILE" ]] && return
    local limit=20 project=
    while [[ $# -gt 0 ]]; do case "$1" in --limit) limit="$2"; shift 2;; --project) project="$2"; shift 2;; *) shift;; esac; done
    echo "## Memoria Persistente" && echo ""
    local src
    if [[ -n "$project" ]]; then
        src=$(grep "\"project\":\"$project\"" "$STORE_FILE" 2>/dev/null | tac | head -n "$limit")
    else
        src=$(tac "$STORE_FILE" | head -n "$limit")
    fi
    echo "$src" | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local ts=$(echo "$line" | grep -o '"ts":"[^"]*"' | cut -d'"' -f4 | cut -d'T' -f1)
        local type=$(echo "$line" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
        local title=$(echo "$line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
        local topic=$(echo "$line" | grep -o '"topic_key":"[^"]*"' | cut -d'"' -f4)
        echo "- [$ts] ($type) $title [$topic]"
    done
}

cmd_stats() {
    [[ ! -f "$STORE_FILE" ]] && { echo "No hay memory store"; return; }
    local total=$(wc -l < "$STORE_FILE")
    echo "Estadisticas — Total: $total entradas"
    echo "Por tipo:" && grep -o '"type":"[^"]*"' "$STORE_FILE" | cut -d'"' -f4 | \
        sort | uniq -c | sort -rn | awk '{ printf "  %s: %d\n", $2, $1 }'
    echo "Por familia topic_key:" && grep -o '"topic_key":"[^/"]*' "$STORE_FILE" | \
        cut -d'"' -f4 | sort | uniq -c | sort -rn | head -10 | \
        awk '{ printf "  %s/: %d\n", $2, $1 }'
    echo "Por concepto:" && grep -o '"concepts":\[[^]]*\]' "$STORE_FILE" | sed 's/.*\[//;s/\].*//' | \
        tr ',' '\n' | tr -d '"' | sed '/^$/d' | sort | uniq -c | sort -rn | head -5 | \
        awk '{ printf "  %s: %d\n", $2, $1 }'
    echo "Revisiones (topic_keys con rev>1):" && grep -o '"rev":[0-9]*' "$STORE_FILE" | \
        cut -d: -f2 | awk '$1>1{count++; sum+=$1} END{printf "  %d topics evolucionados, avg %.1f revs\n", count+0, (count>0?sum/count:0)}'
}

cmd_entity() {
    local action="${1:-list}" query= etype= proj=
    shift 2>/dev/null || true
    while [[ $# -gt 0 ]]; do case "$1" in --type) etype="$2"; shift 2;; --project) proj="$2"; shift 2;; *) query="$1"; shift;; esac; done
    [[ ! -f "$STORE_FILE" ]] && { echo "No hay entidades registradas"; return; }
    if [[ "$action" == "list" ]]; then
        echo "## Entidades Registradas"
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
            echo "$t — $ts: $c"
        done
    else echo "Uso: entity {list|find} [nombre] [--type tipo] [--project proj]"; fi
}

cmd_suggest_topic() {
    local type="${1:-}" title="${2:-}"
    [[ -z "$type" || -z "$title" ]] && { echo "Uso: suggest-topic {type} {title}"; return; }
    suggest_topic_key "$type" "$title"
}

cmd_session_summary() {
    local goal= discoveries= accomplished= files= project=
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --goal) goal="$2"; shift 2 ;;
            --discoveries) discoveries="$2"; shift 2 ;;
            --accomplished) accomplished="$2"; shift 2 ;;
            --files) files="$2"; shift 2 ;;
            --project) project="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    [[ -z "$accomplished" ]] && { echo "Error: --accomplished requerido"; return 1; }
    local content="Goal: ${goal:-not specified}"
    [[ -n "$discoveries" ]] && content="$content | Discoveries: $discoveries"
    content="$content | Accomplished: $accomplished"
    [[ -n "$files" ]] && content="$content | Files: $files"
    cmd_save --type "session-summary" --title "Session $(date +%Y-%m-%d)" \
        --content "$content" --concepts "session" \
        --topic "session/$(date +%Y-%m-%d)" ${project:+--project "$project"}
}

case "${1:-help}" in
    save) shift; cmd_save "$@" ;;
    search) shift; cmd_search "$@" ;;
    context) shift; cmd_context "$@" ;;
    stats) cmd_stats ;;
    entity) shift; cmd_entity "$@" ;;
    suggest-topic) shift; cmd_suggest_topic "$@" ;;
    session-summary) shift; cmd_session_summary "$@" ;;
    *) cat <<'USAGE'
Uso: memory-store.sh {command} [options]

Commands:
  save              Save observation (supports --what/--why/--where/--learned)
  search            Full-text search with scoring
  context           Recent memories (progressive disclosure)
  stats             Statistics by type, topic family, concept
  entity            Entity memory (list/find)
  suggest-topic     Suggest topic_key for type+title
  session-summary   Save session summary (--goal/--discoveries/--accomplished/--files)

Save options:
  --type TYPE       Observation type (decision, bug, pattern, discovery, etc.)
  --title TITLE     Brief identifier
  --content TEXT    Free-form content (or use structured fields below)
  --what TEXT       What happened
  --why TEXT        Why it matters
  --where TEXT      Where in the codebase
  --learned TEXT    Key takeaway
  --topic KEY       Topic key (auto-suggested if omitted: type/slug)
  --concepts CSV    Comma-separated concept tags
  --project NAME    Associated project
USAGE
    ;;
esac
