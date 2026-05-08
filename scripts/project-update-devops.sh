#!/usr/bin/env bash
# project-update-devops.sh — wrapper que resuelve config real desde
# ~/.azure/projects/ y delega en project-update-devops-scan.py.
#
# Diseño: los nombres reales (org, project, iteration) viven en
# ficheros locales del usuario y nunca atraviesan la API cloud.
# Este wrapper no compara strings que vengan de la sesión LLM,
# así que es inmune al estado del unmask del Shield para tool-args.
#
# Uso:
#   bash scripts/project-update-devops.sh                   # 1 solo .json en ~/.azure/projects/
#   bash scripts/project-update-devops.sh <ruta-al-json>    # múltiples .json
#
# Sale 2 si no hay config válida o hay ambigüedad.

set -euo pipefail

CFG_DIR="$HOME/.azure/projects"
if [[ ! -d "$CFG_DIR" ]]; then
  echo "ERROR: $CFG_DIR no existe." >&2
  exit 2
fi

CFG_FILE="${1:-}"
if [[ -z "$CFG_FILE" ]]; then
  # auto-pick si solo hay uno
  shopt -s nullglob
  files=("$CFG_DIR"/*.json)
  shopt -u nullglob
  if (( ${#files[@]} == 0 )); then
    echo "ERROR: no hay ficheros .json en $CFG_DIR" >&2
    exit 2
  elif (( ${#files[@]} > 1 )); then
    echo "ERROR: $CFG_DIR contiene varios .json — pasa la ruta explícita:" >&2
    for f in "${files[@]}"; do echo "  $f" >&2; done
    exit 2
  fi
  CFG_FILE="${files[0]}"
fi

if [[ ! -f "$CFG_FILE" ]]; then
  echo "ERROR: $CFG_FILE no existe." >&2
  exit 2
fi

# Extract fields with python (handles unicode + spaces). The slug used
# downstream is the codename from the file's `_codename` field — that
# string is real on disk and goes straight to the python scanner without
# round-tripping through the LLM.
IFS=$'\t' read -r SLUG ORG PROJECT ITERATION PAT_FILE < <(python3 - "$CFG_FILE" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
parts = [
    d.get('_codename','') or '',
    d.get('org','') or '',
    d.get('project','') or '',
    d.get('iteration','') or '',
    d.get('pat_file','') or '',
]
print('\t'.join(parts))
PYEOF
)

missing=()
[[ -z "$SLUG" ]]      && missing+=("_codename")
[[ -z "$ORG" ]]       && missing+=("org")
[[ -z "$PROJECT" ]]   && missing+=("project")
[[ -z "$ITERATION" ]] && missing+=("iteration")
if (( ${#missing[@]} > 0 )); then
  echo "ERROR: faltan campos en $CFG_FILE: ${missing[*]}" >&2
  exit 2
fi

# pat_file por defecto: "<slug>-pat" o el fallback hardcoded del scanner
# Si pat_file está vacío, el scanner usa su lógica de fallback.

# Hand off to the scanner. Args go straight as argv to python — no
# string comparison vs LLM-side literals here.
echo "[wrapper] config: $CFG_FILE" >&2
exec python3 scripts/project-update-devops-scan.py \
  --slug "$SLUG" \
  --org "$ORG" \
  --project "$PROJECT" \
  --iteration "$ITERATION"
