#!/bin/bash
# memory-save.sh — Save, upsert, entity, session-summary (sourced by memory-store.sh)
# SPEC-019: contradiction tracking (supersedes). SPEC-020: TTL (expires_at).

cmd_save() {
    local type= title= content= concepts= topic_key= project= rev=1 expires_days=
    local what= why= where= learned=
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type) type="$2"; shift 2 ;; --title) title="$2"; shift 2 ;;
            --content) content="$2"; shift 2 ;; --concepts) concepts="$2"; shift 2 ;;
            --topic) topic_key="$2"; shift 2 ;; --project) project="$2"; shift 2 ;;
            --what) what="$2"; shift 2 ;; --why) why="$2"; shift 2 ;;
            --where) where="$2"; shift 2 ;; --learned) learned="$2"; shift 2 ;;
            --expires) expires_days="$2"; shift 2 ;; *) shift ;;
        esac
    done
    [[ -z "$type" || -z "$title" ]] && { echo "Error: --type, --title requeridos"; exit 1; }

    # Build structured content from W/W/W/L fields
    if [[ -n "$what" || -n "$why" || -n "$where" || -n "$learned" ]]; then
        local structured=""
        [[ -n "$what" ]] && structured="What: $what"
        [[ -n "$why" ]] && structured="$structured | Why: $why"
        [[ -n "$where" ]] && structured="$structured | Where: $where"
        [[ -n "$learned" ]] && structured="$structured | Learned: $learned"
        [[ -n "$content" ]] && content="$content | $structured" || content="$structured"
    fi
    [[ -z "$content" ]] && { echo "Error: --content or --what required"; exit 1; }

    content=$(echo "$content" | redact_private | head -c 2000)
    content="${content//$'\n'/\\n}"; content="${content//$'\r'/\\r}"; content="${content//$'\t'/\\t}"
    local tokens_est=$((${#content} / 4))
    local hash=$(hash_content "$content") now=$(iso8601_now)

    [[ -z "$topic_key" ]] && topic_key=$(suggest_topic_key "$type" "$title")

    # Parse concepts
    local concepts_json="[]"
    if [[ -n "$concepts" ]]; then
        concepts_json="["; IFS=',' read -ra CPTS <<< "$concepts"
        for i in "${!CPTS[@]}"; do
            concepts_json="$concepts_json\"${CPTS[$i]// /}\""
            [[ $i -lt $((${#CPTS[@]} - 1)) ]] && concepts_json="$concepts_json,"
        done; concepts_json="$concepts_json]"
    fi

    # SPEC-020: TTL
    local expires_at="null"
    if [[ -n "$expires_days" ]]; then
        expires_at=$(date -u -d "+${expires_days} days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "null")
    fi

    # UPSERT + SPEC-019 contradiction
    local supersedes="null"
    if [[ -n "$topic_key" && "$topic_key" != "null" && -f "$STORE_FILE" ]]; then
        local old_line=$(grep -F "\"topic_key\":\"$topic_key\"" "$STORE_FILE" 2>/dev/null | tail -1 || true)
        if [[ -n "$old_line" ]]; then
            rev=$(($(echo "$old_line" | grep -o '"rev":[0-9]*' | cut -d: -f2) + 1))
            local old_content=$(echo "$old_line" | grep -o '"content":"[^"]*"' | sed 's/"content":"//;s/"$//' | head -c 200)
            [[ -n "$old_content" && "$old_content" != "$content" ]] && supersedes="$old_content"
            local temp_file=$(mktemp)
            grep -vF "\"topic_key\":\"$topic_key\"" "$STORE_FILE" > "$temp_file" || true
            mv "$temp_file" "$STORE_FILE"
        fi
    fi

    # Dedup (15 min)
    if [[ -f "$STORE_FILE" ]] && grep -qF "\"hash\":\"$hash\"" "$STORE_FILE" 2>/dev/null; then
        local recent_ts=$(grep -F "\"hash\":\"$hash\"" "$STORE_FILE" | tail -1 | grep -o '"ts":"[^"]*"' | cut -d'"' -f4)
        local recent_epoch=$(date -d "$recent_ts" +%s 2>/dev/null || echo 0)
        local cutoff=$(date -u -d '15 minutes ago' +%s 2>/dev/null || echo 0)
        if [[ $recent_epoch -gt $cutoff ]]; then echo "⊘ Duplicado omitido"; return 0; fi
    fi

    local json="{\"ts\":\"$now\",\"type\":\"$type\",\"title\":\"$title\",\"content\":\"$content\",\"concepts\":$concepts_json,\"tokens_est\":$tokens_est,\"topic_key\":\"${topic_key}\",\"project\":\"${project:-null}\",\"hash\":\"$hash\",\"rev\":$rev"
    [[ "$supersedes" != "null" ]] && json="$json,\"supersedes\":\"$supersedes\""
    [[ "$expires_at" != "null" ]] && json="$json,\"expires_at\":\"$expires_at\""
    echo "$json}" >> "$STORE_FILE"
    echo "✓ Guardado: $title (topic: $topic_key, rev: $rev)"
    _maybe_rebuild_index
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

cmd_session_summary() {
    local goal= discoveries= accomplished= files= project=
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --goal) goal="$2"; shift 2 ;; --discoveries) discoveries="$2"; shift 2 ;;
            --accomplished) accomplished="$2"; shift 2 ;; --files) files="$2"; shift 2 ;;
            --project) project="$2"; shift 2 ;; *) shift ;;
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
