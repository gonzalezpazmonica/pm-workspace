#!/usr/bin/env bash
set -uo pipefail
# bus-factor-scan.sh -- Wrapper orquestador para bus-factor-scan.py
# SE-252 -- Bus Factor Shield

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# -- Defaults -----------------------------------------------------------------
BF_OUTPUT_DIR="${BF_OUTPUT_DIR:-$PROJECT_DIR/output/bus-factor}"
PROJECT_PATH=""
OUTPUT_FILE=""
FORMAT="json"

# -- Ayuda --------------------------------------------------------------------
usage() {
  cat >&2 <<'EOF'
Usage: bus-factor-scan.sh --project <path> [options]

Options:
  --project <path>   Directorio del repositorio a analizar (obligatorio)
  --output  <file>   Fichero JSON de salida (default: BF_OUTPUT_DIR/<name>.json)
  --format  <fmt>    Formato de salida: json (default)
  --help             Muestra esta ayuda

Variables de entorno:
  BF_OUTPUT_DIR           Directorio de salida (default: output/bus-factor/)
  BF_OWNERSHIP_THRESHOLD  Score minimo para ser owner (default: 0.50)
  BF_MIN_COMMITS          Commits minimos para incluir archivo (default: 5)
  BF_EXCLUDE_PATTERNS     Patrones a excluir, separados por comas
  BF_MODULE_DEPTH         Profundidad de agrupacion de modulos (default: 2)
  BF_MAX_HISTORY_DEPTH    Limite de commits a analizar (0 = sin limite)
EOF
  exit 1
}

# -- Parseo de argumentos -----------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_PATH="$2"; shift 2 ;;
    --output)  OUTPUT_FILE="$2";  shift 2 ;;
    --format)  FORMAT="$2";       shift 2 ;;
    --help|-h) usage ;;
    *) echo "ERROR: argumento desconocido: $1" >&2; usage ;;
  esac
done

if [[ -z "$PROJECT_PATH" ]]; then
  echo "ERROR: --project es obligatorio" >&2
  usage
fi

# -- Verificar dependencias ---------------------------------------------------
for dep in git python3; do
  if ! command -v "$dep" &>/dev/null; then
    echo "ERROR: dependencia no encontrada: $dep" >&2
    exit 1
  fi
done

# -- Verificar que PROJECT_PATH es un repo git --------------------------------
if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "ERROR: directorio no existe: $PROJECT_PATH" >&2
  exit 1
fi

if ! git -C "$PROJECT_PATH" rev-parse --git-dir &>/dev/null; then
  echo "ERROR: no es un repositorio git: $PROJECT_PATH" >&2
  exit 1
fi

PROJECT_NAME="$(basename "$PROJECT_PATH")"

# -- Preparar directorio de output --------------------------------------------
mkdir -p "$BF_OUTPUT_DIR"

# Verificar que BF_OUTPUT_DIR esta en .gitignore del workspace
GITIGNORE="$PROJECT_DIR/.gitignore"
BF_OUTPUT_REL="${BF_OUTPUT_DIR#$PROJECT_DIR/}"
if [[ -f "$GITIGNORE" ]]; then
  if ! grep -qF "output/" "$GITIGNORE" && ! grep -qF "$BF_OUTPUT_REL" "$GITIGNORE"; then
    echo "$BF_OUTPUT_REL/" >> "$GITIGNORE"
    echo "INFO: anadido $BF_OUTPUT_REL/ a .gitignore" >&2
  fi
fi

# -- Determinar fichero de output ---------------------------------------------
if [[ -z "$OUTPUT_FILE" ]]; then
  TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date -u +%Y%m%d)"
  OUTPUT_FILE="$BF_OUTPUT_DIR/${PROJECT_NAME}-${TIMESTAMP}.json"
fi

# -- Ejecutar motor Python ----------------------------------------------------
echo "INFO: escaneando $PROJECT_PATH ..." >&2

PYTHON_SCRIPT="$SCRIPT_DIR/bus-factor-scan.py"
if [[ ! -f "$PYTHON_SCRIPT" ]]; then
  echo "ERROR: no encontrado $PYTHON_SCRIPT" >&2
  exit 1
fi

python3 "$PYTHON_SCRIPT" \
  --project "$PROJECT_NAME" \
  --output  "$OUTPUT_FILE" \
  "$PROJECT_PATH"

echo "INFO: output escrito en $OUTPUT_FILE" >&2

# Mostrar resumen
if command -v jq &>/dev/null; then
  jq '{project: .project, summary: .summary, generated_at: .generated_at}' "$OUTPUT_FILE"
else
  python3 -c "
import json, sys
d = json.load(open('$OUTPUT_FILE'))
print(json.dumps({'project': d['project'], 'summary': d['summary'], 'generated_at': d['generated_at']}, indent=2))
"
fi
