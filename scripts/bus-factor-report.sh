#!/usr/bin/env bash
set -uo pipefail
# bus-factor-report.sh -- Informe ejecutivo del scan de Bus Factor.
# SE-252 -- Bus Factor Shield

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BF_OUTPUT_DIR="${BF_OUTPUT_DIR:-$PROJECT_DIR/output/bus-factor}"

# -- Defaults -----------------------------------------------------------------
PROJECT_PATH=""
FORMAT="markdown"
OUTPUT_FILE=""

# -- Ayuda --------------------------------------------------------------------
usage() {
  cat >&2 <<'EOF'
Usage: bus-factor-report.sh --project <path> [options]

Options:
  --project <path>   Directorio del repositorio (obligatorio)
  --format  <fmt>    Formato: markdown|json (default: markdown)
  --output  <file>   Fichero de salida (default: stdout)
  --help             Muestra esta ayuda
EOF
  exit 1
}

# -- Parseo de argumentos -----------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_PATH="$2"; shift 2 ;;
    --format)  FORMAT="$2";       shift 2 ;;
    --output)  OUTPUT_FILE="$2";  shift 2 ;;
    --help|-h) usage ;;
    *) echo "ERROR: argumento desconocido: $1" >&2; usage ;;
  esac
done

if [[ -z "$PROJECT_PATH" ]]; then
  echo "ERROR: --project es obligatorio" >&2; usage
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

# -- Generar informe ----------------------------------------------------------
RESULT=$(python3 - "$SCAN_JSON" "$FORMAT" << 'PYEOF'
import json
import sys

scan_file = sys.argv[1]
fmt       = sys.argv[2]

with open(scan_file) as f:
    data = json.load(f)

project  = data.get("project", "desconocido")
gen_at   = data.get("generated_at", "")
modules  = data.get("modules", [])
summary  = data.get("summary", {})
warnings = data.get("warnings", [])

risk_rank = {"CRITICAL": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1, "UNKNOWN": 0}
modules_sorted = sorted(modules, key=lambda m: -risk_rank.get(m.get("risk_level", "LOW"), 0))

if fmt == "json":
    report = {
        "project": project,
        "generated_at": gen_at,
        "summary": summary,
        "warnings": warnings,
        "modules_by_risk": [
            {
                "name":       m["name"],
                "bus_factor": m["bus_factor"],
                "risk_level": m["risk_level"],
                "owners":     [o["dev"] for o in m.get("owners", [])],
                "file_count": len(m.get("files", [])),
            }
            for m in modules_sorted
        ],
        "recommended_actions": [],
    }
    # Acciones recomendadas
    critical_mods = [m for m in modules if m.get("risk_level") == "CRITICAL"]
    if critical_mods:
        report["recommended_actions"].append({
            "priority": "P0",
            "action": "Generar CONTEXT_DOME.md para modulos CRITICAL",
            "modules": [m["name"] for m in critical_mods],
            "command": "bash scripts/context-dome-generate.sh --project <path> --min-risk CRITICAL",
        })
    high_mods = [m for m in modules if m.get("risk_level") == "HIGH"]
    if high_mods:
        report["recommended_actions"].append({
            "priority": "P1",
            "action": "Planificar knowledge transfer para modulos HIGH",
            "modules": [m["name"] for m in high_mods],
            "command": "bash scripts/bus-factor-distribute.sh --project <path> --target <dev>",
        })
    print(json.dumps(report, indent=2, ensure_ascii=False))

else:
    # Markdown
    lines = []
    lines.append(f"# Informe Bus Factor -- {project}")
    lines.append(f"\nGenerado: {gen_at}  ")
    lines.append(f"Scan: `{scan_file}`\n")

    lines.append("## Resumen ejecutivo\n")
    lines.append(f"| Metrica | Valor |")
    lines.append(f"|---------|-------|")
    lines.append(f"| Total modulos | {summary.get('total_modules', 0)} |")
    lines.append(f"| CRITICAL (BF=1) | **{summary.get('critical', 0)}** |")
    lines.append(f"| HIGH (BF=2) | {summary.get('high', 0)} |")
    lines.append(f"| MEDIUM (BF<=3) | {summary.get('medium', 0)} |")
    lines.append(f"| LOW | {summary.get('low', 0)} |")
    lines.append("")

    if warnings:
        lines.append("## Advertencias del scan\n")
        for w in warnings:
            lines.append(f"- `{w}`")
        lines.append("")

    lines.append("## Modulos por nivel de riesgo\n")
    lines.append("| Modulo | BF | Riesgo | Owners | Archivos |")
    lines.append("|--------|-----|--------|--------|----------|")
    for m in modules_sorted:
        owners_str = ", ".join(o["dev"] for o in m.get("owners", [])[:3])
        if len(m.get("owners", [])) > 3:
            owners_str += f" (+{len(m['owners'])-3})"
        lines.append(
            f"| `{m['name']}` | {m['bus_factor']} | {m['risk_level']} "
            f"| {owners_str} | {len(m.get('files', []))} |"
        )
    lines.append("")

    # Acciones recomendadas
    lines.append("## Acciones recomendadas\n")
    critical_mods = [m for m in modules if m.get("risk_level") == "CRITICAL"]
    high_mods     = [m for m in modules if m.get("risk_level") == "HIGH"]

    if critical_mods:
        lines.append("### P0 -- Modulos CRITICAL (accion inmediata)\n")
        for m in critical_mods:
            owners_str = ", ".join(o["dev"] for o in m.get("owners", []))
            lines.append(f"- **{m['name']}**: BF=1, unico conocedor: `{owners_str}`")
        lines.append(f"\n```bash\nbash scripts/context-dome-generate.sh --project <path> --min-risk CRITICAL\n```\n")

    if high_mods:
        lines.append("### P1 -- Modulos HIGH (planificar este sprint)\n")
        for m in high_mods:
            lines.append(f"- **{m['name']}**: BF={m['bus_factor']}")
        lines.append(f"\n```bash\nbash scripts/bus-factor-distribute.sh --project <path> --target <dev>\n```\n")

    if not critical_mods and not high_mods:
        lines.append("No hay modulos de riesgo P0 o P1. Revisar mensualmente.\n")

    print("\n".join(lines))
PYEOF
)

# -- Output -------------------------------------------------------------------
if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  echo "$RESULT" > "$OUTPUT_FILE"
  echo "INFO: informe escrito en $OUTPUT_FILE" >&2
else
  echo "$RESULT"
fi
