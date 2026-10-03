#!/bin/bash
# setup-memory.sh — Inicializa estructura de auto memory para un proyecto
# Uso: ./scripts/setup-memory.sh [nombre-proyecto]
#
# Si no se proporciona nombre (o es vacío), usa el basename de la raíz git actual.
# Destino: $SAVIA_MEMORY_DIR si está definida; si no, ~/.savia/projects/<nombre>/memory.
# Idempotente: solo crea los ficheros que falten; nunca sobrescribe notas existentes.
# Exit: 0 ok · 1 fallo de escritura · 2 nombre de proyecto o entorno inválido.

set -euo pipefail

PROJECT_NAME="${1:-}"
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")"
fi

# El nombre es un único componente de ruta: sin '/', sin '.'/'..', sin guion inicial,
# sin caracteres de control y como máximo 255 bytes (NAME_MAX).
invalid_name() {
    echo "❌ nombre de proyecto inválido: $1" >&2
    echo "   Debe ser un único nombre de directorio (sin '/', '.', '..', guion inicial ni saltos de línea; ≤255 bytes)." >&2
    exit 2
}
case "$PROJECT_NAME" in
    . | .. | -* | */*) invalid_name "$PROJECT_NAME" ;;
esac
if [[ "$PROJECT_NAME" == *[[:cntrl:]]* ]]; then
    invalid_name "$(printf '%q' "$PROJECT_NAME")"
fi
if [ "$(printf '%s' "$PROJECT_NAME" | LC_ALL=C wc -c)" -gt 255 ]; then
    invalid_name "${PROJECT_NAME:0:40}… (demasiado largo)"
fi

if [ -n "${SAVIA_MEMORY_DIR:-}" ]; then
    MEMORY_DIR="$SAVIA_MEMORY_DIR"
elif [ -n "${HOME:-}" ]; then
    MEMORY_DIR="$HOME/.savia/projects/$PROJECT_NAME/memory"
else
    echo "❌ HOME no está definida y tampoco SAVIA_MEMORY_DIR: no sé dónde crear la memoria." >&2
    exit 2
fi

TODAY="$(date +%Y-%m-%d)"

# write_if_absent <destino> — lee el contenido de stdin y lo publica de forma atómica
# solo si el destino no existe. Devuelve 0 si lo creó y 3 si ya existía. Un temporal
# + ln (que falla si el destino existe) evita ficheros a medias y carreras entre
# ejecuciones simultáneas.
write_if_absent() {
    local dst="$1" tmp rc=0
    if [ -e "$dst" ]; then
        cat >/dev/null
        return 3
    fi
    tmp="$(mktemp "$dst.tmp.XXXXXX")" || return 1
    if ! cat >"$tmp"; then
        echo "❌ No se pudo escribir $tmp" >&2
        rm -f "$tmp"
        return 1
    fi
    if ! ln "$tmp" "$dst" 2>/dev/null; then
        if [ -e "$dst" ]; then
            rc=3
        else
            echo "❌ No se pudo crear $dst" >&2
            rc=1
        fi
    fi
    rm -f "$tmp"
    return "$rc"
}

# report <rc> <fichero> — 0 creado, 3 ya existía; cualquier otro código aborta con exit 1.
report() {
    case "$1" in
        0) echo "✅ $2 creado" ;;
        3) echo "⏭️  $2 ya existe" ;;
        *) echo "❌ Abortado: no se pudo crear $2 en $MEMORY_DIR" >&2; exit 1 ;;
    esac
}

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

# MEMORY.md: el nombre y la fecha se insertan como datos (printf %s), nunca como
# patrón de sed, para que '&', '/' o palabras como FECHA no alteren la plantilla.
rc=0
{
    printf '# Memory — %s\n> Última sync: %s\n' "$PROJECT_NAME" "$TODAY"
    cat << 'MEMEOF'

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
} | write_if_absent "$MEMORY_DIR/MEMORY.md" || rc=$?
report "$rc" "MEMORY.md"

# Topic files
for TOPIC in sprint-history architecture debugging team-patterns devops-notes; do
    TITLE=""
    for word in ${TOPIC//-/ }; do TITLE+="${TITLE:+ }${word^}"; done
    rc=0
    printf '# %s — %s\n\n> Actualizado: %s\n\n---\n\n(Sin notas todavía. Claude añadirá contenido aquí automáticamente.)\n' \
        "$TITLE" "$PROJECT_NAME" "$TODAY" | write_if_absent "$MEMORY_DIR/$TOPIC.md" || rc=$?
    report "$rc" "$TOPIC.md"
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
echo "  - Edita con /memory en Claude Code / OpenCode"
