#!/usr/bin/env bash
set -uo pipefail
# context-dome-generate.sh -- Genera CONTEXT_DOME.md por modulo con BF bajo.
# SE-252 -- Bus Factor Shield

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BF_OUTPUT_DIR="${BF_OUTPUT_DIR:-$PROJECT_DIR/output/bus-factor}"

# -- Defaults -----------------------------------------------------------------
PROJECT_PATH=""
MODULE_FILTER=""
MIN_RISK="HIGH"
DRY_RUN=false

# -- Ayuda --------------------------------------------------------------------
usage() {
  cat >&2 <<'EOF'
Usage: context-dome-generate.sh --project <path> [options]

Options:
  --project   <path>   Directorio del repositorio (obligatorio)
  --module    <name>   Solo generar cupula para este modulo
  --min-risk  <level>  Riesgo minimo: CRITICAL|HIGH|MEDIUM|LOW (default: HIGH)
  --dry-run            Muestra que se generaria sin escribir
  --help               Muestra esta ayuda
EOF
  exit 1
}

# -- Parseo de argumentos -----------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)  PROJECT_PATH="$2"; shift 2 ;;
    --module)   MODULE_FILTER="$2"; shift 2 ;;
    --min-risk) MIN_RISK="$2";      shift 2 ;;
    --dry-run)  DRY_RUN=true;       shift ;;
    --help|-h)  usage ;;
    *) echo "ERROR: argumento desconocido: $1" >&2; usage ;;
  esac
done

if [[ -z "$PROJECT_PATH" ]]; then
  echo "ERROR: --project es obligatorio" >&2
  usage
fi

PROJECT_NAME="$(basename "$PROJECT_PATH")"

# -- Encontrar JSON del scan mas reciente -------------------------------------
find_latest_scan() {
  local dir="$1"
  local name="$2"
  # Buscar el mas reciente por fecha de modificacion
  local found
  found=$(ls -t "$dir"/"${name}"-*.json 2>/dev/null | head -1) || true
  if [[ -z "$found" ]]; then
    # Fallback: cualquier JSON en el directorio
    found=$(ls -t "$dir"/*.json 2>/dev/null | head -1) || true
  fi
  echo "$found"
}

SCAN_JSON=$(find_latest_scan "$BF_OUTPUT_DIR" "$PROJECT_NAME")
if [[ -z "$SCAN_JSON" ]] || [[ ! -f "$SCAN_JSON" ]]; then
  echo "ERROR: no se encontro JSON de scan en $BF_OUTPUT_DIR" >&2
  echo "INFO: ejecuta primero: bash scripts/bus-factor-scan.sh --project $PROJECT_PATH" >&2
  exit 1
fi

echo "INFO: usando scan: $SCAN_JSON" >&2

# -- Mapeo de nivel de riesgo a numero (para comparacion) ---------------------
risk_to_num() {
  case "$1" in
    CRITICAL) echo 4 ;;
    HIGH)     echo 3 ;;
    MEDIUM)   echo 2 ;;
    LOW)      echo 1 ;;
    *)        echo 0 ;;
  esac
}

MIN_RISK_NUM=$(risk_to_num "$MIN_RISK")

# -- Extraer modulos elegibles del JSON ---------------------------------------
MODULES_JSON=$(python3 -c "
import json, sys

data = json.load(open('$SCAN_JSON'))
min_num = $MIN_RISK_NUM
risk_map = {'CRITICAL': 4, 'HIGH': 3, 'MEDIUM': 2, 'LOW': 1}
module_filter = '$MODULE_FILTER'

result = []
for mod in data.get('modules', []):
    rl = mod.get('risk_level', 'LOW')
    if risk_map.get(rl, 0) < min_num:
        continue
    if module_filter and mod['name'] != module_filter:
        continue
    result.append({
        'name': mod['name'],
        'path': mod['path'],
        'bus_factor': mod['bus_factor'],
        'risk_level': rl,
        'owners': mod.get('owners', []),
        'warnings': mod.get('warnings', []),
    })

print(json.dumps(result))
" 2>/dev/null)

MODULE_COUNT=$(python3 -c "import json,sys; print(len(json.loads('$MODULES_JSON')))" 2>/dev/null || echo 0)

if [[ "$MODULE_COUNT" -eq 0 ]]; then
  echo "INFO: no hay modulos con riesgo >= $MIN_RISK" >&2
  exit 0
fi

echo "INFO: generando cupulas para $MODULE_COUNT modulos ..." >&2

# -- Funciones auxiliares de extraccion ---------------------------------------

extract_purpose() {
  local mod_path="$1"
  local full_path="$PROJECT_PATH/$mod_path"
  local purpose=""

  # 1. CONTEXT.md del modulo
  if [[ -f "$full_path/CONTEXT.md" ]]; then
    purpose=$(head -20 "$full_path/CONTEXT.md" | grep -v "^#" | grep -v "^---" | grep -v "^$" | head -5 | tr '\n' ' ')
  fi

  # 2. README.md del modulo
  if [[ -z "$purpose" ]] && [[ -f "$full_path/README.md" ]]; then
    purpose=$(grep -A3 "^## " "$full_path/README.md" 2>/dev/null | head -4 | grep -v "^##" | grep -v "^$" | head -2 | tr '\n' ' ')
    if [[ -z "$purpose" ]]; then
      purpose=$(head -5 "$full_path/README.md" | grep -v "^#" | grep -v "^$" | head -2 | tr '\n' ' ')
    fi
  fi

  # 3. Comentarios cabecera del primer archivo fuente
  if [[ -z "$purpose" ]]; then
    local first_file
    first_file=$(find "$full_path" -maxdepth 1 -type f \( -name "*.py" -o -name "*.ts" -o -name "*.go" -o -name "*.cs" -o -name "*.java" \) 2>/dev/null | head -1)
    if [[ -n "$first_file" ]]; then
      purpose=$(head -10 "$first_file" | grep -E "^(#|//|/\*|\*)" | grep -v "^#!/" | head -3 | sed 's|^[#/*\s]*||' | tr '\n' ' ')
    fi
  fi

  echo "${purpose:-[sin descripcion detectada -- documentar manualmente]}"
}

extract_key_decisions() {
  local mod_path="$1"
  local full_path="$PROJECT_PATH/$mod_path"

  # git log buscando patrones de decision
  local patterns="why:|because|NOTE:|HACK:|FIXME:|decision:|tradeoff:|SE-|SPEC-"
  local log_output
  log_output=$(git -C "$PROJECT_PATH" log --oneline --grep="$patterns" \
    --all --max-count=20 -- "$mod_path/" 2>/dev/null) || true

  if [[ -z "$log_output" ]]; then
    echo "[sin decisiones documentadas en commits -- revisar ADRs del proyecto]"
  else
    echo "$log_output"
  fi
}

extract_dependencies() {
  local mod_path="$1"
  local full_path="$PROJECT_PATH/$mod_path"

  # Detectar imports segun extension
  local deps=""
  if [[ -d "$full_path" ]]; then
    # Python
    deps+=$(grep -rh "^import \|^from " "$full_path" --include="*.py" 2>/dev/null | sort -u | head -10)
    # TypeScript/JavaScript
    deps+=$(grep -rh "^import " "$full_path" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep "from " | sed "s/.*from '\(.*\)'.*/\1/" | sort -u | head -10)
    # Go
    deps+=$(grep -rh '^\s*"' "$full_path" --include="*.go" 2>/dev/null | sed 's/^\s*//' | sort -u | head -10)
    # C#
    deps+=$(grep -rh "^using " "$full_path" --include="*.cs" 2>/dev/null | sort -u | head -10)
  fi

  if [[ -z "${deps// /}" ]]; then
    echo "[sin dependencias externas detectadas automaticamente]"
  else
    echo "$deps" | head -15
  fi
}

extract_runbook() {
  local mod_path="$1"
  local full_path="$PROJECT_PATH/$mod_path"
  local runbook=""
  local sources=0

  # Makefile targets
  if [[ -f "$full_path/Makefile" ]]; then
    local targets
    targets=$(grep -E "^[a-zA-Z_-]+:" "$full_path/Makefile" 2>/dev/null | sed 's/:.*//' | head -8)
    if [[ -n "$targets" ]]; then
      runbook+="### Makefile targets\n\`\`\`\n$targets\n\`\`\`\n"
      ((sources++)) || true
    fi
  fi

  # package.json scripts
  if [[ -f "$full_path/package.json" ]]; then
    local scripts
    scripts=$(python3 -c "import json; d=json.load(open('$full_path/package.json')); [print(f'  npm run {k}: {v}') for k,v in d.get('scripts',{}).items()]" 2>/dev/null | head -8)
    if [[ -n "$scripts" ]]; then
      runbook+="### npm scripts\n\`\`\`\n$scripts\n\`\`\`\n"
      ((sources++)) || true
    fi
  fi

  # README ## Usage section
  if [[ -f "$full_path/README.md" ]]; then
    local usage_section
    usage_section=$(awk '/^## (Usage|Uso|Getting Started|Quick Start)/{found=1; next} found && /^## /{exit} found{print}' "$full_path/README.md" 2>/dev/null | head -15)
    if [[ -n "$usage_section" ]]; then
      runbook+="### README Usage\n$usage_section\n"
      ((sources++)) || true
    fi
  fi

  # Dockerfile CMD / ENTRYPOINT
  if [[ -f "$full_path/Dockerfile" ]]; then
    local docker_cmd
    docker_cmd=$(grep -E "^(CMD|ENTRYPOINT|RUN)" "$full_path/Dockerfile" 2>/dev/null | tail -3)
    if [[ -n "$docker_cmd" ]]; then
      runbook+="### Dockerfile\n\`\`\`dockerfile\n$docker_cmd\n\`\`\`\n"
      ((sources++)) || true
    fi
  fi

  # Calcular confianza
  local confidence="low"
  if [[ $sources -ge 2 ]]; then
    confidence="high"
  elif [[ $sources -eq 1 ]]; then
    confidence="medium"
  fi

  if [[ -z "${runbook// /}" ]] || [[ $sources -eq 0 ]]; then
    echo "CONFIDENCE:low"
    echo "[sin runbook detectado -- documentar manualmente]"
  else
    echo "CONFIDENCE:$confidence"
    printf '%b' "$runbook"
  fi
}

extract_recent_commits() {
  local mod_path="$1"
  # Excluir merge commits, chore, format, typo
  git -C "$PROJECT_PATH" log \
    --oneline \
    --max-count=10 \
    --no-merges \
    --invert-grep \
    --grep="^chore\|^format\|^typo\|^style" \
    -- "$mod_path/" 2>/dev/null || true
}

# -- Generar CONTEXT_DOME.md por modulo ---------------------------------------

generate_dome() {
  local mod_json="$1"

  local mod_name bus_factor risk_level owners_json warnings_json
  mod_name=$(echo "$mod_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['name'])")
  bus_factor=$(echo "$mod_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['bus_factor'])")
  risk_level=$(echo "$mod_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['risk_level'])")
  owners_json=$(echo "$mod_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d['owners']))")
  warnings_json=$(echo "$mod_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d['warnings']))")

  local full_path="$PROJECT_PATH/$mod_name"
  local dome_path="$full_path/CONTEXT_DOME.md"
  local generated_at
  generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%S)

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY-RUN: generaria $dome_path (BF=$bus_factor, risk=$risk_level)"
    return
  fi

  # Crear directorio si no existe (modulo sin directorio real)
  if [[ ! -d "$full_path" ]]; then
    echo "WARN: directorio no existe: $full_path (saltando)" >&2
    return
  fi

  # Extraer datos
  local purpose
  purpose=$(extract_purpose "$mod_name")

  local key_decisions
  key_decisions=$(extract_key_decisions "$mod_name")

  local deps
  deps=$(extract_dependencies "$mod_name")

  local runbook_raw
  runbook_raw=$(extract_runbook "$mod_name")
  local runbook_confidence
  runbook_confidence=$(echo "$runbook_raw" | head -1 | sed 's/CONFIDENCE://')
  local runbook_content
  runbook_content=$(echo "$runbook_raw" | tail -n +2)

  local recent_commits
  recent_commits=$(extract_recent_commits "$mod_name")

  # Construir owners YAML y tabla markdown
  local owners_yaml owners_table
  owners_yaml=$(echo "$owners_json" | python3 -c "
import json,sys
owners = json.load(sys.stdin)
for o in owners:
    print(f'  - {o[\"dev\"]}')
" 2>/dev/null || echo "  - desconocido")

  owners_table=$(echo "$owners_json" | python3 -c "
import json,sys
owners = json.load(sys.stdin)
print('| Developer | Score | Archivos propios |')
print('|-----------|-------|-----------------|')
for o in owners:
    print(f'| {o[\"dev\"]} | {o[\"score\"]} | {o[\"files_owned\"]} |')
" 2>/dev/null || echo "| desconocido | - | - |")

  # Calcular plan de distribucion sugerido
  local dist_plan
  if [[ "$bus_factor" -le 1 ]]; then
    dist_plan="**URGENTE**: BF=1. Identificar backup owner esta semana. Usar bus-factor-distribute.sh --target <candidato>."
  elif [[ "$bus_factor" -le 2 ]]; then
    dist_plan="Riesgo HIGH. Planificar sesion de pair-review con segundo dev antes del proximo sprint."
  else
    dist_plan="Riesgo controlado. Revisar trimestralmente."
  fi

  # Escribir CONTEXT_DOME.md
  cat > "$dome_path" << DOMEEOF
---
module: $mod_name
bus_factor: $bus_factor
risk_level: $risk_level
knowledge_owners:
$owners_yaml
generated_at: $generated_at
spec: SE-252
warnings: $warnings_json
runbook_confidence: $runbook_confidence
---

# Context Dome -- $mod_name

## Proposito

$purpose

## Decisiones no obvias

$key_decisions

## Dependencias criticas

$deps

## Runbook minimo

$runbook_content

## Knowledge owners actuales

$owners_table

## Plan de distribucion sugerido

$dist_plan

## Historial de cambios relevantes

$recent_commits
DOMEEOF

  echo "OK: $dome_path (BF=$bus_factor, risk=$risk_level, runbook=$runbook_confidence)" >&2
}

# -- Iterar sobre modulos elegibles -------------------------------------------

python3 -c "
import json, sys

data = json.loads('''$MODULES_JSON''')
for i, mod in enumerate(data):
    print(json.dumps(mod))
" | while IFS= read -r mod_json; do
  generate_dome "$mod_json"
done

echo "INFO: generacion completada" >&2
