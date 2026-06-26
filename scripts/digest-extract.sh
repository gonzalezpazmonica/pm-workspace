#!/usr/bin/env bash
# digest-extract.sh — Capa 0 universal de extracción via markitdown (SE-172)
set -uo pipefail
#
# Usage: bash scripts/digest-extract.sh <input-file> [--output <md-file>] [--external]
#
# AC-01: Produce Markdown con front-matter (mime, hash, timestamp)
# AC-05: usa convert_local() por defecto — rechaza URIs no-file
# AC-07: umask 077 + rechaza paths fuera de WORKSPACE_ROOT sin --external
# AC-06: si markitdown falla, exit 1 con WARNING (caller hace fallback)

set -uo pipefail

# ── Configuración ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

INPUT_FILE=""
OUTPUT_FILE=""
EXTERNAL=false

# ── Parse args ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --external)
      EXTERNAL=true
      shift
      ;;
    -*)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "$INPUT_FILE" ]]; then
        INPUT_FILE="$1"
      else
        echo "ERROR: Multiple input files not supported" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$INPUT_FILE" ]]; then
  echo "Usage: bash scripts/digest-extract.sh <input-file> [--output <md-file>] [--external]" >&2
  exit 1
fi

# ── Seguridad: resolver path absoluto ────────────────────────────────────────
# AC-07: rechazar paths fuera de WORKSPACE_ROOT salvo --external
REAL_INPUT="$(realpath -m "$INPUT_FILE" 2>/dev/null || echo "$INPUT_FILE")"

if [[ "$EXTERNAL" == "false" ]]; then
  # Verificar que el path está dentro de WORKSPACE_ROOT
  REAL_WORKSPACE="$(realpath "$WORKSPACE_ROOT" 2>/dev/null || echo "$WORKSPACE_ROOT")"
  if [[ "$REAL_INPUT" != "$REAL_WORKSPACE"* ]]; then
    echo "WARNING: Path outside WORKSPACE_ROOT rejected: $REAL_INPUT" >&2
    echo "WARNING: Use --external to allow paths outside workspace" >&2
    exit 1
  fi
fi

# Verificar que el fichero existe
if [[ ! -f "$REAL_INPUT" ]]; then
  echo "WARNING: Input file not found: $REAL_INPUT" >&2
  exit 1
fi

# ── Detectar MIME ─────────────────────────────────────────────────────────────
EXT="${REAL_INPUT##*.}"
EXT_LOWER="${EXT,,}"
case "$EXT_LOWER" in
  pdf)       MIME="application/pdf" ;;
  docx)      MIME="application/vnd.openxmlformats-officedocument.wordprocessingml.document" ;;
  xlsx)      MIME="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" ;;
  xls)       MIME="application/vnd.ms-excel" ;;
  pptx)      MIME="application/vnd.openxmlformats-officedocument.presentationml.presentation" ;;
  ppt)       MIME="application/vnd.ms-powerpoint" ;;
  png)       MIME="image/png" ;;
  jpg|jpeg)  MIME="image/jpeg" ;;
  gif)       MIME="image/gif" ;;
  webp)      MIME="image/webp" ;;
  bmp)       MIME="image/bmp" ;;
  tiff|tif)  MIME="image/tiff" ;;
  html|htm)  MIME="text/html" ;;
  csv)       MIME="text/csv" ;;
  json)      MIME="application/json" ;;
  xml)       MIME="application/xml" ;;
  zip)       MIME="application/zip" ;;
  epub)      MIME="application/epub+zip" ;;
  msg)       MIME="application/vnd.ms-outlook" ;;
  txt|md)    MIME="text/plain" ;;
  vtt)       MIME="text/vtt" ;;
  mp3|m4a|wav|ogg) MIME="audio/${EXT_LOWER}" ;;
  *)         MIME="application/octet-stream" ;;
esac

# ── Hash del fichero original ─────────────────────────────────────────────────
HASH_ORIGINAL=$(sha256sum "$REAL_INPUT" 2>/dev/null | awk '{print $1}' || echo "unknown")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BASENAME=$(basename "$REAL_INPUT")

# ── Verificar markitdown disponible ──────────────────────────────────────────
if ! python3 -c "import markitdown" 2>/dev/null; then
  echo "WARNING: markitdown not installed. Install with: pip install 'markitdown[pdf,docx,pptx,xlsx]'" >&2
  exit 1
fi

# ── Extraer con markitdown (AC-05: convert_local por defecto) ─────────────────
# umask 077 antes de escribir temp files (AC-07)
umask 077
TMPFILE=$(mktemp /tmp/digest-extract-XXXXXX.md)

EXTRACT_OK=false
MARKITDOWN_VERSION=$(python3 -c "import markitdown; print(markitdown.__version__)" 2>/dev/null || echo "unknown")
PAGES_COUNT="unknown"

python3 - "$REAL_INPUT" "$TMPFILE" <<'PYEOF'
import sys
import os

input_path = sys.argv[1]
output_path = sys.argv[2]

try:
    from markitdown import MarkItDown
    # AC-05: usar convert_local por defecto — no permite URIs remotas
    md = MarkItDown()
    result = md.convert_local(input_path)
    content = result.text_content if hasattr(result, 'text_content') else str(result)
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)
    sys.exit(0)
except AttributeError:
    # Fallback: markitdown <0.1.x no tiene convert_local — usar convert con file://
    try:
        from markitdown import MarkItDown
        md = MarkItDown()
        # Sanitizar: rechazar URIs no-file (AC-05)
        if not os.path.isabs(input_path):
            print(f"WARNING: Non-absolute path rejected", file=sys.stderr)
            sys.exit(1)
        file_uri = f"file://{input_path}"
        result = md.convert(file_uri)
        content = result.text_content if hasattr(result, 'text_content') else str(result)
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(content)
        sys.exit(0)
    except Exception as e2:
        print(f"WARNING: markitdown extraction failed: {e2}", file=sys.stderr)
        sys.exit(1)
except Exception as e:
    print(f"WARNING: markitdown extraction failed: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF

EXTRACT_EXIT=$?

if [[ $EXTRACT_EXIT -ne 0 ]]; then
  rm -f "$TMPFILE"
  echo "WARNING: markitdown failed on $REAL_INPUT — caller should use fallback parser" >&2
  exit 1
fi

EXTRACT_OK=true

# Contar páginas aproximadas (líneas de doble-newline en el markdown)
if [[ -f "$TMPFILE" ]]; then
  PAGES_COUNT=$(grep -c "^$" "$TMPFILE" 2>/dev/null || echo "unknown")
fi

# ── Detección de idioma básica ────────────────────────────────────────────────
LANG_DETECTED="unknown"
if python3 -c "import langdetect" 2>/dev/null && [[ -f "$TMPFILE" ]]; then
  LANG_DETECTED=$(python3 - "$TMPFILE" <<'PYEOF2'
import sys
try:
    from langdetect import detect
    with open(sys.argv[1], 'r', encoding='utf-8', errors='ignore') as f:
        text = f.read(2000)
    if len(text.strip()) > 20:
        print(detect(text))
    else:
        print("unknown")
except Exception:
    print("unknown")
PYEOF2
)
fi

# ── Construir output con front-matter ────────────────────────────────────────
{
  cat <<FRONTMATTER
---
mime: "${MIME}"
source_file: "${BASENAME}"
hash_original: "${HASH_ORIGINAL}"
timestamp: "${TIMESTAMP}"
markitdown_version: "${MARKITDOWN_VERSION}"
lang_detected: "${LANG_DETECTED}"
pages_approx: ${PAGES_COUNT}
extractor: "markitdown"
---

FRONTMATTER
  cat "$TMPFILE"
} > "${TMPFILE}.out"

rm -f "$TMPFILE"

# ── Escribir output ───────────────────────────────────────────────────────────
if [[ -n "$OUTPUT_FILE" ]]; then
  # Si el output va fuera del workspace, solo permitir con --external
  REAL_OUTPUT="$(realpath -m "$OUTPUT_FILE" 2>/dev/null || echo "$OUTPUT_FILE")"
  if [[ "$EXTERNAL" == "false" ]]; then
    REAL_WORKSPACE="$(realpath "$WORKSPACE_ROOT" 2>/dev/null || echo "$WORKSPACE_ROOT")"
    if [[ "$REAL_OUTPUT" != "$REAL_WORKSPACE"* ]]; then
      echo "WARNING: Output path outside WORKSPACE_ROOT rejected: $REAL_OUTPUT" >&2
      rm -f "${TMPFILE}.out"
      exit 1
    fi
  fi
  mv "${TMPFILE}.out" "$OUTPUT_FILE"
  echo "OK: Extracted to $OUTPUT_FILE" >&2
else
  # Stdout
  cat "${TMPFILE}.out"
  rm -f "${TMPFILE}.out"
fi

exit 0
