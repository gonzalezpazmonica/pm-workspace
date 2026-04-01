#!/bin/bash
# post-compaction.sh - Hook que inyecta contexto de memoria tras compactación
# Ejecutado por SessionStart(compact) para recuperar decisiones y patrones previos

set -euo pipefail

# ============================================================================
# DETECTAR PROYECTO
# ============================================================================

detect_project() {
    # 1. Buscar en CLAUDE.local.md
    if [[ -f "CLAUDE.local.md" ]]; then
        grep -i "^project:" "CLAUDE.local.md" | head -1 | cut -d':' -f2- | xargs || true
        return
    fi

    # 2. Desde git remote
    if git rev-parse --git-dir > /dev/null 2>&1; then
        git config --get remote.origin.url | grep -o '[^/]*\.git$' | sed 's/\.git$//' || true
        return
    fi

    # 3. Desde nombre de directorio
    basename "$(pwd)"
}

# ============================================================================
# LEER Y FORMATEAR MEMORIA
# ============================================================================

format_memory_context() {
    local store_file="${PROJECT_ROOT:-.}/output/.memory-store.jsonl"

    [[ ! -f "$store_file" ]] && return

    local project=$(detect_project)
    local -A entries_by_type

    # Leer últimas 20 entradas (o del proyecto específico)
    tail -20 "$store_file" | while IFS= read -r line; do
        local ts=$(echo "$line" | grep -o '"ts":"[^"]*"' | cut -d'"' -f4 | cut -d'T' -f1)
        local type=$(echo "$line" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
        local title=$(echo "$line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
        local content=$(echo "$line" | grep -o '"content":"[^"]*"' | \
                       sed 's/"content":"//' | sed 's/"$//' | head -c 100)

        # Agrupar por tipo
        case "$type" in
            decision)
                echo "DECISION|$ts|$title|$content"
                ;;
            bug)
                echo "BUG|$ts|$title|$content"
                ;;
            pattern)
                echo "PATTERN|$ts|$title|$content"
                ;;
            convention)
                echo "CONVENTION|$ts|$title|$content"
                ;;
            discovery)
                echo "DISCOVERY|$ts|$title|$content"
                ;;
        esac
    done
}

# ============================================================================
# MAIN - Generar salida de inyección
# ============================================================================

store_file="${PROJECT_ROOT:-.}/output/.memory-store.jsonl"

# ── SESSION-HOT REINJECTION (SPEC-068) ──
SESSION_HOT="$HOME/.claude/projects/-home-monica-claude/memory/session-hot.md"
if [[ -f "$SESSION_HOT" ]] && [[ -s "$SESSION_HOT" ]]; then
    echo "## Session Continuity (pre-compact extraction)"
    echo ""
    tail -20 "$SESSION_HOT"
    echo ""
    : > "$SESSION_HOT"  # consumed — truncate for next cycle
fi

# Si no existe memoria, salir tras session-hot
[[ ! -f "$store_file" ]] && exit 0

project=$(detect_project)

echo "## Memoria Persistente — Contexto recuperado"
echo ""

# Procesar por tipo — compact loop
declare -A section_names=([DECISION]="Decisiones" [BUG]="Bugs" [PATTERN]="Patrones" [CONVENTION]="Convenciones" [DISCOVERY]="Descubrimientos")
declare -A section_items

while IFS='|' read -r type ts title content; do
    [[ -z "$type" ]] && continue
    section_items[$type]+="- [$ts] $title — ${content:0:60}..."$'\n'
done < <(format_memory_context)

for key in DECISION BUG PATTERN CONVENTION DISCOVERY; do
    if [[ -n "${section_items[$key]:-}" ]]; then
        echo "### ${section_names[$key]}"
        printf '%s' "${section_items[$key]}"
        echo ""
    fi
done
