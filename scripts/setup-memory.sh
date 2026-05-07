#!/bin/bash
# setup-memory.sh — Inicializa estructura de auto memory para un proyecto
# Uso: ./scripts/setup-memory.sh [nombre-proyecto]
#
# Si no se proporciona nombre, usa el basename del directorio git actual.

set -euo pipefail

PROJECT_NAME="${1:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
MEMORY_DIR="${SAVIA_MEMORY_DIR:-$HOME/.savia/projects/$PROJECT_NAME/memory}"

echo "══════════════════════════════════════════════════════"
echo "  Setup Auto Memory — $PROJECT_NAME"
echo "══════════════════════════════════════════════════════"

if [ -d "$MEMORY_DIR" ]; then
    echo "⚠️  Ya existe: $MEMORY_DIR"
    echo "   Creando solo los ficheros que falten..."
else
    mkdir -p "$MEMORY_DIR"
    echo "✅ Directorio creado: $MEMORY_DIR"
fi

# Crear MEMORY.md si no existe
if [ ! -f "$MEMORY_DIR/MEMORY.md" ]; then
    cat > "$MEMORY_DIR/MEMORY.md" << 'MEMEOF'
# Memory — PROJECT_NAME
> Última sync: FECHA

## Resumen
- Proyecto: [descripción breve]
- Stack: [lenguajes y frameworks principales]
- Sprint actual: Sprint N

## Topic Files
- `sprint-history.md` — Velocidad, burndown, impedimentos
- `architecture.md` — Decisiones arquitectónicas, ADRs
- `debugging.md` — Problemas resueltos y workarounds
- `team-patterns.md` — Convenciones y preferencias del equipo
- `devops-notes.md` — CI/CD, entornos, secretos

## Insights Recientes
- (pendiente de primera sync)
MEMEOF
    sed -i "s/PROJECT_NAME/$PROJECT_NAME/g" "$MEMORY_DIR/MEMORY.md"
    sed -i "s/FECHA/$(date +%Y-%m-%d)/g" "$MEMORY_DIR/MEMORY.md"
    echo "✅ MEMORY.md creado"
else
    echo "⏭️  MEMORY.md ya existe"
fi

# Crear topic files si no existen
for TOPIC in sprint-history architecture debugging team-patterns devops-notes; do
    if [ ! -f "$MEMORY_DIR/$TOPIC.md" ]; then
        TITLE=$(echo "$TOPIC" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
        cat > "$MEMORY_DIR/$TOPIC.md" << TOPICEOF
# $TITLE — $PROJECT_NAME

> Actualizado: $(date +%Y-%m-%d)

---

(Sin notas todavía. Claude añadirá contenido aquí automáticamente.)
TOPICEOF
        echo "✅ $TOPIC.md creado"
    else
        echo "⏭️  $TOPIC.md ya existe"
    fi
done

echo ""
echo "══════════════════════════════════════════════════════"
echo "  ✅ Auto Memory inicializada para: $PROJECT_NAME"
echo "  📁 $MEMORY_DIR"
echo "══════════════════════════════════════════════════════"
echo ""
echo "Uso:"
echo "  - Claude guardará notas aquí automáticamente"
echo "  - Ejecuta /memory-sync para consolidar manualmente"
echo "  - Edita con /memory en Claude Code"
