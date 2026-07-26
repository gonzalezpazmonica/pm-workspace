#!/bin/bash
# memory-write-gate.sh — SE-270 S6: validates memory entries before writing
# Checks: stability (topic must not change too often), cross-task relevance,
# confidence >= threshold
# Usage:
#   memory-write-gate.sh --content "..." --type decision --topic-key foo/bar [--confidence 0.8]
#   memory-write-gate.sh --json '{"content":"...","type":"decision",...}'
# Exit: 0 = PASS, 1 = REJECT
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORE_FILE="${PROJECT_ROOT:-.}/output/.memory-store.jsonl"
CONFIDENCE_THRESHOLD="${MEMORY_GATE_CONFIDENCE:-0.5}"
STABILITY_MAX_UPDATES="${MEMORY_GATE_STABILITY_MAX:-3}"
STABILITY_WINDOW_DAYS="${MEMORY_GATE_STABILITY_WINDOW:-30}"
RELEVANCE_MIN_CONCEPTS="${MEMORY_GATE_RELEVANCE_CONCEPTS:-1}"

log() { echo "[memory-write-gate] $*" >&2; }
pass() { echo "PASS: $*"; exit 0; }
reject() { echo "REJECT: $*" >&2; exit 1; }

map_quality_to_confidence() {
  case "${1:-}" in
    high) echo "0.9" ;; medium) echo "0.7" ;; low) echo "0.4" ;;
    unverified) echo "0.3" ;; *) echo "0.5" ;;
  esac
}

parse_json_field() {
  local json="$1" field="$2"
  echo "$json" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    print(d.get('$field', ''))
except:
    print('')
" 2>/dev/null
}

if [[ $# -eq 0 ]]; then
  echo "Usage: memory-write-gate.sh --content TEXT --type TYPE [--title TITLE] [--topic-key KEY] [--confidence N] [--project PROJECT] [--quality QUALITY]" >&2
  exit 0
fi

json_in=""
if [[ "${1:-}" == "--json" ]]; then
  json_in="$2"
  content=$(parse_json_field "$json_in" "content")
  type=$(parse_json_field "$json_in" "type")
  title=$(parse_json_field "$json_in" "title")
  topic_key=$(parse_json_field "$json_in" "topic_key")
  confidence=$(parse_json_field "$json_in" "confidence")
  quality=$(parse_json_field "$json_in" "quality")
  concepts_json=$(parse_json_field "$json_in" "concepts")
  project=$(parse_json_field "$json_in" "project")
  source=$(parse_json_field "$json_in" "source")
else
  content= type= title= topic_key= confidence= quality= project= concepts_json= source=
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --content) content="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      --title) title="$2"; shift 2 ;;
      --topic-key) topic_key="$2"; shift 2 ;;
      --confidence) confidence="$2"; shift 2 ;;
      --quality) quality="$2"; shift 2 ;;
      --project) project="$2"; shift 2 ;;
      --concepts) concepts_json="$2"; shift 2 ;;
      --source) source="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
fi

# human instruction bypass
if [[ -n "${source:-}" && "$source" == "user:explicit" ]]; then
  pass "instruccion humana explicita — bypass de gate"
fi

[[ -z "$content" ]] && reject "contenido vacio — no se puede validar"
[[ -z "$type" ]] && reject "tipo no declarado — requerido para gate de escritura"

if [[ -z "$confidence" && -n "$quality" ]]; then
  confidence=$(map_quality_to_confidence "$quality")
fi
if [[ -z "$confidence" ]]; then
  confidence=0.5
fi

if [[ ! "$confidence" =~ ^[0-9]+\.?[0-9]*$ ]]; then
  reject "confidence no es numerico: '$confidence'"
fi

if (( $(echo "$confidence < $CONFIDENCE_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
  reject "confianza insuficiente: ${confidence} < umbral ${CONFIDENCE_THRESHOLD} (calidad=${quality:-no declarada})"
fi

# Stability check
if [[ -n "$topic_key" && "$topic_key" != "null" && -f "$STORE_FILE" ]]; then
  cutoff_epoch=$(date -u -d "${STABILITY_WINDOW_DAYS} days ago" +%s 2>/dev/null || echo 0)
  update_count=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    line_ts=$(echo "$line" | grep -o '"ts":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
    [[ -z "$line_ts" ]] && continue
    line_epoch=$(date -d "$line_ts" +%s 2>/dev/null || echo 0)
    if [[ "$line_epoch" -gt "$cutoff_epoch" ]]; then
      ((update_count++)) || true
    fi
  done < <(grep -F "topic_key\":\"$topic_key" "$STORE_FILE" 2>/dev/null || true)

  if (( update_count >= STABILITY_MAX_UPDATES )); then
    reject "inestable: topic_key '$topic_key' actualizado ${update_count} veces en ${STABILITY_WINDOW_DAYS} dias (max: ${STABILITY_MAX_UPDATES})"
  fi
fi

# Cross-task relevance
concept_count=0
if [[ -n "$concepts_json" && "$concepts_json" != "[]" ]]; then
  concept_count=$(echo "$concepts_json" | tr -d '[]"' | tr ',' '\n' | sed '/^$/d' | wc -l)
fi
if (( concept_count < RELEVANCE_MIN_CONCEPTS )); then
  proper_noun_count=$(echo "$content" | grep -oP '\b[A-Z][a-z]{3,}\b' | wc -l || echo 0)
  if (( proper_noun_count < 2 )); then
    reject "relevancia cruzada insuficiente: ${concept_count} conceptos explicitos, <2 nombres propios — hecho probablemente local a una tarea"
  fi
fi

# Transience
if [[ "$type" == "feedback" || "$type" == "episode" ]]; then
  reject "tipo '$type' es transitorio por defecto — usar memoria de sesion, no permanente"
fi

<<<<<<< HEAD
MIN_CONTENT_LENGTH="${MEMORY_GATE_MIN_CONTENT_LENGTH:-40}"
content_len=${#content}
if (( content_len < MIN_CONTENT_LENGTH )) && [[ "$type" != "config" && "$type" != "entity" ]]; then
  reject "contenido demasiado corto (${content_len} chars) para memoria permanente (min: ${MIN_CONTENT_LENGTH})"
=======
content_len=${#content}
if (( content_len < 60 )) && [[ "$type" != "config" && "$type" != "entity" ]]; then
  reject "contenido demasiado corto (${content_len} chars) para memoria permanente"
>>>>>>> origin/main
fi

pass "estable, relevante, confianza=${confidence}, tipo=${type}"
