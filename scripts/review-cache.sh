#!/bin/bash
# review-cache.sh - Gestión de caché de code review
set -euo pipefail

CACHE_DIR="${PROJECT_ROOT:-.}/output/.review-cache"

cmd_stats() {
    if [[ ! -d "$CACHE_DIR" ]]; then
        echo "No hay caché de review"
        return
    fi

    local total_files=$(find "$CACHE_DIR" -name "*.passed" 2>/dev/null | wc -l)
    local cache_size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    local rules_hash_file="$CACHE_DIR/.rules-hash"

    echo "📊 Review Cache Stats"
    echo ""
    echo "  Entradas cacheadas: $total_files"
    echo "  Tamaño en disco:    $cache_size"

    if [[ -f "$rules_hash_file" ]]; then
        echo "  Rules hash:         $(cat "$rules_hash_file" | cut -c1-12)..."
        echo "  Última actualización: $(stat -c %y "$rules_hash_file" 2>/dev/null | cut -d'.' -f1)"
    fi

    # Estimar ahorro
    if [[ $total_files -gt 0 ]]; then
        echo ""
        echo "  💡 Estimación: ~$((total_files * 500)) tokens ahorrados en reviews cacheados"
    fi
}

cmd_clear() {
    if [[ ! -d "$CACHE_DIR" ]]; then
        echo "No hay caché que limpiar"
        return
    fi

    local count=$(find "$CACHE_DIR" -name "*.passed" 2>/dev/null | wc -l)
    rm -f "$CACHE_DIR"/*.passed 2>/dev/null || true
    rm -f "$CACHE_DIR/.rules-hash" 2>/dev/null || true
    echo "✓ Caché limpiada: $count entradas eliminadas"
}

cmd_list() {
    if [[ ! -d "$CACHE_DIR" ]]; then
        echo "No hay caché de review"
        return
    fi

    echo "📋 Entradas cacheadas (más recientes primero):"
    echo ""
    find "$CACHE_DIR" -name "*.passed" -printf '%T@ %p\n' 2>/dev/null | \
        sort -rn | head -20 | while read -r ts file; do
        local content=$(cat "$file" 2>/dev/null)
        echo "  $(echo "$content")"
    done
}

case "${1:-help}" in
    stats) cmd_stats ;;
    clear) cmd_clear ;;
    list) cmd_list ;;
    *) cat <<'EOF'
Uso: review-cache.sh <cmd>
  stats  — Estadísticas de caché (entradas, tamaño, ahorro estimado)
  clear  — Limpiar toda la caché
  list   — Listar entradas cacheadas recientes
EOF
    ;;
esac
