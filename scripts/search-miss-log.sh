#!/usr/bin/env bash
# search-miss-log.sh — registra cuando la heurística tier-based bajó a T4/T5
# Uso: scripts/search-miss-log.sh <tier> <category> <query> <reason>
# Ej:  scripts/search-miss-log.sh T4 CONCEPTO "mass balance v3" "no en GLOSSARY"
set -euo pipefail
TIER="${1:?tier T4|T5}"; CAT="${2:?PERSONA|CONCEPTO|REGLA|CODIGO|EVENTO}"
QUERY="${3:?query}"; REASON="${4:?por qué falló índice}"
PROJECT="${SAVIA_PROJECT:-$(basename "$(pwd)")}"
LOG_GLOBAL="$HOME/.savia/search-misses.jsonl"
LOG_PROJECT=""
[[ -d "projects/${PROJECT}/output" ]] && LOG_PROJECT="projects/${PROJECT}/output/audits/search-misses.jsonl"
TS="$(date -Iseconds)"
ENTRY=$(printf '{"ts":"%s","project":"%s","tier":"%s","category":"%s","query":"%s","reason":"%s"}\n' \
  "$TS" "$PROJECT" "$TIER" "$CAT" "$QUERY" "$REASON")
echo "$ENTRY" >> "$LOG_GLOBAL"
[[ -n "$LOG_PROJECT" ]] && { mkdir -p "$(dirname "$LOG_PROJECT")"; echo "$ENTRY" >> "$LOG_PROJECT"; }
echo "✓ search-miss registrada [$TIER/$CAT] → $LOG_GLOBAL"
