#!/usr/bin/env bash
set -uo pipefail
# bus-factor-distribute.sh -- Plan de knowledge transfer por developer objetivo.
# SE-252 -- Bus Factor Shield

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BF_OUTPUT_DIR="${BF_OUTPUT_DIR:-$PROJECT_DIR/output/bus-factor}"

# -- Defaults -----------------------------------------------------------------
PROJECT_PATH=""
TARGET_DEV=""
OUTPUT_FILE=""
FORMAT="markdown"

# -- Ayuda --------------------------------------------------------------------
usage() {
  cat >&2 <<'EOF'
Usage: bus-factor-distribute.sh --project <path> --target <dev> [options]

Options:
  --project <path>   Directorio del repositorio (obligatorio)
  --target  <dev>    Developer objetivo para el plan de conocimiento (obligatorio)
  --output  <file>   Fichero de salida (default: stdout)
  --format  <fmt>    Formato: markdown|json (default: markdown)
  --help             Muestra esta ayuda

El plan ordena modulos por: risk_level DESC, bus_factor ASC, loc ASC
EOF
  exit 1
}

# -- Parseo de argumentos -----------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_PATH="$2"; shift 2 ;;
    --target)  TARGET_DEV="$2";   shift 2 ;;
    --output)  OUTPUT_FILE="$2";  shift 2 ;;
    --format)  FORMAT="$2";       shift 2 ;;
    --help|-h) usage ;;
    *) echo "ERROR: argumento desconocido: $1" >&2; usage ;;
  esac
done

if [[ -z "$PROJECT_PATH" ]]; then
  echo "ERROR: --project es obligatorio" >&2; usage
fi
if [[ -z "$TARGET_DEV" ]]; then
  echo "ERROR: --target es obligatorio" >&2; usage
fi

PROJECT_NAME="$(basename "$PROJECT_PATH")"

# -- Encontrar JSON del scan --------------------------------------------------
SCAN_JSON=$(ls -t "$BF_OUTPUT_DIR"/"${PROJECT_NAME}"-*.json 2>/dev/null | head -1 \
            || ls -t "$BF_OUTPUT_DIR"/*.json 2>/dev/null | head -1 || true)

if [[ -z "$SCAN_JSON" ]] || [[ ! -f "$SCAN_JSON" ]]; then
  echo "ERROR: no se encontro JSON de scan en $BF_OUTPUT_DIR" >&2
  echo "INFO: ejecuta primero: bash scripts/bus-factor-scan.sh --project $PROJECT_PATH" >&2
  exit 1
fi

echo "INFO: usando scan: $SCAN_JSON" >&2

# -- Generar plan via Python --------------------------------------------------
RESULT=$(python3 - "$SCAN_JSON" "$TARGET_DEV" "$PROJECT_PATH" "$FORMAT" << 'PYEOF'
import json
import os
import subprocess
import sys

scan_file  = sys.argv[1]
target_dev = sys.argv[2]
proj_path  = sys.argv[3]
fmt        = sys.argv[4]

with open(scan_file) as f:
    data = json.load(f)

risk_rank = {"CRITICAL": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1}

def count_lines(path):
    """Cuenta lineas de codigo en un directorio."""
    total = 0
    try:
        for root, dirs, files in os.walk(path):
            dirs[:] = [d for d in dirs if d not in ("node_modules", "vendor", ".git")]
            for fname in files:
                fp = os.path.join(root, fname)
                try:
                    with open(fp, "rb") as fh:
                        total += fh.read().count(b"\n")
                except (IOError, OSError):
                    pass
    except OSError:
        pass
    return total

plan_items = []
for mod in data.get("modules", []):
    mod_name = mod["name"]
    bf = mod["bus_factor"]
    rl = mod["risk_level"]

    # Archivos que el target NO conoce (no es owner)
    unknown_files = []
    for fdata in mod.get("files", []):
        owner_devs = [o["dev"] for o in fdata.get("owners", [])]
        if target_dev not in owner_devs:
            unknown_files.append(fdata["path"])

    loc = count_lines(os.path.join(proj_path, mod_name))
    dome_path = os.path.join(proj_path, mod_name, "CONTEXT_DOME.md")
    has_dome = os.path.isfile(dome_path)

    plan_items.append({
        "module":        mod_name,
        "bus_factor":    bf,
        "risk_level":    rl,
        "risk_rank":     risk_rank.get(rl, 0),
        "unknown_files": unknown_files,
        "unknown_count": len(unknown_files),
        "total_files":   len(mod.get("files", [])),
        "loc":           loc,
        "has_dome":      has_dome,
        "dome_path":     dome_path if has_dome else None,
    })

# Ordenar: risk DESC, bf ASC, loc ASC
plan_items.sort(key=lambda x: (-x["risk_rank"], x["bus_factor"], x["loc"]))

if fmt == "json":
    output = {
        "target": target_dev,
        "project": data.get("project", ""),
        "generated_at": data.get("generated_at", ""),
        "plan": plan_items,
    }
    print(json.dumps(output, indent=2, ensure_ascii=False))
else:
    # Markdown
    lines = []
    lines.append(f"# Plan de Knowledge Transfer -- {target_dev}")
    lines.append(f"\nProyecto: **{data.get('project', '')}**  ")
    lines.append(f"Generado: {data.get('generated_at', '')}  ")
    lines.append(f"Total modulos en plan: **{len(plan_items)}**\n")
    lines.append("---\n")

    for i, item in enumerate(plan_items, 1):
        pct_unknown = (item["unknown_count"] / max(item["total_files"], 1)) * 100
        dome_ref = f"[CONTEXT_DOME.md]({item['dome_path']})" if item["has_dome"] else "*(cupula no generada aun)*"

        lines.append(f"## {i}. {item['module']}")
        lines.append(f"\n- **Riesgo**: {item['risk_level']}  ")
        lines.append(f"- **Bus Factor**: {item['bus_factor']}  ")
        lines.append(f"- **Archivos desconocidos**: {item['unknown_count']}/{item['total_files']} ({pct_unknown:.0f}%)  ")
        lines.append(f"- **Lineas de codigo**: {item['loc']:,}  ")
        lines.append(f"- **Cupula de contexto**: {dome_ref}  ")

        if item["unknown_files"]:
            lines.append(f"\n### Archivos a estudiar ({min(len(item['unknown_files']), 10)} primeros):")
            for fp in item["unknown_files"][:10]:
                lines.append(f"- `{fp}`")

        lines.append("")

    print("\n".join(lines))
PYEOF
)

# -- Output -------------------------------------------------------------------
if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  echo "$RESULT" > "$OUTPUT_FILE"
  echo "INFO: plan escrito en $OUTPUT_FILE" >&2
else
  echo "$RESULT"
fi
