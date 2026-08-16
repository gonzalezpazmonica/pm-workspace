#!/usr/bin/env bash
set -uo pipefail
# bus-factor-warn.sh -- PostToolUse: avisa si se modifica un archivo con BF=1.
# SE-252 -- Bus Factor Shield. Modo warn-only. NUNCA bloquea (exit 0 siempre).

BF_HOOK_TIMEOUT="${BF_HOOK_TIMEOUT:-3}"
BF_OUTPUT_DIR="${BF_OUTPUT_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}/output/bus-factor}"

# Salida limpia en cualquier error
output_warn() {
  local msg="${1:-}"
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' \
    "$(echo "$msg" | sed 's/"/\\"/g; s/\n/\\n/g')"
  exit 0
}

# Leer input del hook con timeout
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(timeout "${BF_HOOK_TIMEOUT}" cat 2>/dev/null) || true
fi
[[ -z "$INPUT" ]] && exit 0

# Extraer tool_name y file_path del JSON del hook
TOOL_NAME=$(printf '%s' "$INPUT" | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  print(d.get('tool_name',''))
except Exception:
  pass
" 2>/dev/null) || TOOL_NAME=""

# Solo actuar en Write o Edit
case "$TOOL_NAME" in
  Write|Edit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(printf '%s' "$INPUT" | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  ti = d.get('tool_input',{})
  print(ti.get('file_path', ti.get('path', '')))
except Exception:
  pass
" 2>/dev/null) || FILE_PATH=""

[[ -z "$FILE_PATH" ]] && exit 0

# Normalizar path
ABS_PATH=$(python3 -c "import os,sys; print(os.path.abspath(sys.argv[1]))" "$FILE_PATH" 2>/dev/null) || ABS_PATH="$FILE_PATH"

# Buscar JSONs de scan en BF_OUTPUT_DIR
if [[ ! -d "$BF_OUTPUT_DIR" ]]; then
  exit 0
fi

SCAN_FILES=$(ls "$BF_OUTPUT_DIR"/*.json 2>/dev/null) || SCAN_FILES=""
[[ -z "$SCAN_FILES" ]] && exit 0

# Buscar el archivo en los scans disponibles
WARNING_MSG=$(python3 - "$ABS_PATH" "$BF_OUTPUT_DIR" << 'PYEOF'
import json
import os
import sys
import glob

target_path = sys.argv[1]
scan_dir    = sys.argv[2]

target_base = os.path.basename(target_path)

scan_files = sorted(glob.glob(os.path.join(scan_dir, "*.json")), key=os.path.getmtime, reverse=True)

for scan_file in scan_files[:3]:  # Revisar los 3 scans mas recientes
    try:
        with open(scan_file) as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError):
        continue

    for mod in data.get("modules", []):
        for fdata in mod.get("files", []):
            fpath = fdata.get("path", "")
            # Match por basename o por suffix del path
            if not (fpath == target_base or
                    target_path.endswith(fpath) or
                    os.path.basename(fpath) == target_base):
                continue

            bf = fdata.get("bus_factor", 0)
            if bf != 1:
                continue

            owners = fdata.get("owners", [])
            owner_str = owners[0]["dev"] if owners else "desconocido"
            module_name = mod["name"]
            risk = mod.get("risk_level", "UNKNOWN")

            print(
                f"[BF-WARN] Archivo {fpath} tiene BF=1 "
                f"(unico conocedor: {owner_str}, modulo: {module_name}, riesgo: {risk}). "
                f"Accion: generar cupula de contexto o planificar knowledge transfer."
            )
            sys.exit(0)

PYEOF
2>/dev/null) || WARNING_MSG=""

if [[ -n "$WARNING_MSG" ]]; then
  output_warn "$WARNING_MSG"
fi

exit 0
