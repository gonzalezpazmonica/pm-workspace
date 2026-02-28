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

# Si no existe memoria, salir silenciosamente
[[ ! -f "$store_file" ]] && exit 0

project=$(detect_project)

# Encabezado
echo "## 🧠 Memoria Persistente — Contexto recuperado tras compactación"
echo ""

# Procesar por tipo
declare -a decisions bugs patterns conventions discoveries

while IFS='|' read -r type ts title content; do
    case "$type" in
        DECISION)
            decisions+=("- [$ts] $title — ${content:0:60}...")
            ;;
        BUG)
            bugs+=("- [$ts] $title — ${content:0:60}...")
            ;;
        PATTERN)
            patterns+=("- [$ts] $title — ${content:0:60}...")
            ;;
        CONVENTION)
            conventions+=("- [$ts] $title — ${content:0:60}...")
            ;;
        DISCOVERY)
            discoveries+=("- [$ts] $title — ${content:0:60}...")
            ;;
    esac
done < <(format_memory_context)

# Mostrar secciones no vacías
if [[ ${#decisions[@]} -gt 0 ]]; then
    echo "### Decisiones recientes"
    printf '%s\n' "${decisions[@]}"
    echo ""
fi

if [[ ${#bugs[@]} -gt 0 ]]; then
    echo "### Bugs resueltos"
    printf '%s\n' "${bugs[@]}"
    echo ""
fi

if [[ ${#patterns[@]} -gt 0 ]]; then
    echo "### Patrones"
    printf '%s\n' "${patterns[@]}"
    echo ""
fi

if [[ ${#conventions[@]} -gt 0 ]]; then
    echo "### Convenciones"
    printf '%s\n' "${conventions[@]}"
    echo ""
fi

if [[ ${#discoveries[@]} -gt 0 ]]; then
    echo "### Descubrimientos"
    printf '%s\n' "${discoveries[@]}"
    echo ""
fi

echo "💡 Para buscar en memoria: \`memory-search {query}\`"
echo "💡 Para guardar: \`memory-save --type {tipo} --title '{título}' --content '{contenido}'\`"
