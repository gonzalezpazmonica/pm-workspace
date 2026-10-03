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
# Controles bidi Unicode (U+200E/F, U+202A-202E, U+2066-2069): engañan a la vista en listados.
if printf '%s' "$PROJECT_NAME" | LC_ALL=C grep -qE $'\xe2\x80[\x8e\x8f\xaa-\xae]|\xe2\x81[\xa6-\xa9]'; then
    invalid_name "$(printf '%q' "$PROJECT_NAME") (contiene controles bidi Unicode)"
fi
if [ "$(printf '%s' "$PROJECT_NAME" | LC_ALL=C wc -c)" -gt 255 ]; then
    invalid_name "${PROJECT_NAME:0:40}… (demasiado largo)"
fi

if [ -n "${SAVIA_MEMORY_DIR:-}" ]; then
    MEMORY_DIR="$SAVIA_MEMORY_DIR"
elif [ -n "${HOME:-}" ]; then
    MEMORY_DIR="$HOME/.savia/projects/$PROJECT_NAME/memory"
    # Un symlink en <proyecto>/ o en memory/ haría que mkdir -p y las escrituras
    # salieran de ~/.savia/projects; ~/.savia en sí puede ser un enlace legítimo.
    for link in "$HOME/.savia/projects/$PROJECT_NAME" "$MEMORY_DIR"; do
        if [ -L "$link" ]; then
            echo "❌ $link es un enlace simbólico: me niego a escribir a través de él." >&2
            exit 2
        fi
    done
else
    echo "❌ HOME no está definida y tampoco SAVIA_MEMORY_DIR: no sé dónde crear la memoria." >&2
    exit 2
fi

TODAY="$(date +%Y-%m-%d)"

# Permisos de los ficheros creados: los de la umask, como haría una redirección normal
# (mktemp crea en 0600 y ln conserva el inodo).
FILE_MODE="$(printf '%o' $(( 0666 & ~$(umask) )))"

# write_if_absent <destino> — lee el contenido de stdin y lo publica de forma atómica
# solo si el destino no existe. Devuelve 0 si lo creó y 3 si ya existía. Un temporal
# + ln (que falla si el destino existe) garantiza que nadie lee un fichero a medias y
# que dos ejecuciones simultáneas no se pisan. En sistemas sin hard links (exFAT, SMB)
# cae a mv -n, que sigue siendo un rename atómico sin sobrescribir.
# Se invoca siempre como destino de una tubería, así que corre en un subshell propio:
# sus traps (limpieza del temporal al salir o al recibir INT/TERM) no afectan al script.
write_if_absent() {
    local dst="$1" tmp rc=0
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        cat >/dev/null
        return 3
    fi
    tmp="$(mktemp "$dst.tmp.XXXXXX")" || return 1
    trap 'rm -f "$tmp"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    if ! cat >"$tmp" || ! chmod "$FILE_MODE" "$tmp"; then
        echo "❌ No se pudo escribir $tmp" >&2
        return 1
    fi
    if ! ln "$tmp" "$dst" 2>/dev/null; then
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            rc=3
        elif mv -n "$tmp" "$dst" 2>/dev/null && [ ! -e "$tmp" ]; then
            rc=0
        elif [ -e "$dst" ]; then
            rc=3
        else
            echo "❌ No se pudo crear $dst" >&2
            rc=1
        fi
    fi
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
