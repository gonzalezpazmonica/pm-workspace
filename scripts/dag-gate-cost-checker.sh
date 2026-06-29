#!/usr/bin/env bash
# dag-gate-cost-checker.sh
#
# SE-237: Verifica que en un DAG definido en YAML/JSON, los gates CHEAP
# aparecen antes que MEDIUM y EXPENSIVE (patrón coarse-to-fine).
#
# Uso:
#   dag-gate-cost-checker.sh plan.yaml
#   dag-gate-cost-checker.sh plan.json
#   dag-gate-cost-checker.sh < plan.yaml
#
# Formato de input (YAML o JSON):
#   stages:
#     - name: validate-spec
#       gate_type: CHEAP
#     - name: test-runner
#       gate_type: MEDIUM
#     - name: court-orchestrator
#       gate_type: EXPENSIVE
#
# O con un array plano de steps (se infiere el tipo por nombre):
#   steps:
#     - feasibility-probe
#     - test-runner
#     - court-orchestrator
#
# Exit codes:
#   0 — orden correcto (o DAG vacío)
#   1 — violación de orden detectada
#   2 — error de sintaxis en input
#
# Ref: docs/propuestas/SE-237-coarse-to-fine-dag-pattern.md
#      docs/rules/domain/coarse-to-fine-gates.md

set -euo pipefail

# ── Clasificación de agentes conocidos ──────────────────────────────────────
# Cada agente tiene un coste: CHEAP=1, MEDIUM=2, EXPENSIVE=3
declare -A AGENT_COST
# CHEAP
AGENT_COST["dag-typing-validate"]=1
AGENT_COST["dag-typing-validate.sh"]=1
AGENT_COST["spec-validator"]=1
AGENT_COST["spec-validator.sh"]=1
AGENT_COST["hashline-guard"]=1
AGENT_COST["hashline-guard.sh"]=1
AGENT_COST["validate-bash-global"]=1
AGENT_COST["validate-bash-global.sh"]=1
AGENT_COST["block-force-push"]=1
AGENT_COST["spec-id-duplicates-check"]=1
AGENT_COST["spec-id-duplicates-check.sh"]=1
AGENT_COST["validate-spec"]=1
AGENT_COST["validate-spec.sh"]=1
AGENT_COST["bash-syntax-check"]=1
AGENT_COST["syntax-check"]=1
AGENT_COST["lint"]=1

# MEDIUM
AGENT_COST["feasibility-probe"]=2
AGENT_COST["test-runner"]=2
AGENT_COST["dev-orchestrator"]=2
AGENT_COST["coherence-validator"]=2
AGENT_COST["lint-checks"]=2
AGENT_COST["unit-tests"]=2
AGENT_COST["fast-tests"]=2

# EXPENSIVE
AGENT_COST["court-orchestrator"]=3
AGENT_COST["truth-tribunal-orchestrator"]=3
AGENT_COST["security-attacker"]=3
AGENT_COST["security-defender"]=3
AGENT_COST["dotnet-developer"]=3
AGENT_COST["python-developer"]=3
AGENT_COST["typescript-developer"]=3
AGENT_COST["go-developer"]=3
AGENT_COST["java-developer"]=3
AGENT_COST["rust-developer"]=3
AGENT_COST["ruby-developer"]=3
AGENT_COST["php-developer"]=3
AGENT_COST["mobile-developer"]=3
AGENT_COST["frontend-developer"]=3
AGENT_COST["truth-tribunal"]=3
AGENT_COST["security-audit"]=3

# ── Función: obtener coste de un gate ────────────────────────────────────────
get_gate_cost() {
  local name="$1"
  local type="${2:-}"

  # Si se especifica el tipo explícitamente
  case "${type^^}" in
    CHEAP) echo 1; return ;;
    MEDIUM) echo 2; return ;;
    EXPENSIVE) echo 3; return ;;
  esac

  # Buscar por nombre en la tabla
  if [[ -n "${AGENT_COST[$name]+x}" ]]; then
    echo "${AGENT_COST[$name]}"
    return
  fi

  # Inferir por patrones de nombre
  if [[ "$name" =~ (validate|lint|check|guard|syntax|hash) ]]; then
    echo 1  # CHEAP
  elif [[ "$name" =~ (test|probe|orchestrat|plan) ]]; then
    echo 2  # MEDIUM
  elif [[ "$name" =~ (developer|court|tribunal|attacker|defender|audit) ]]; then
    echo 3  # EXPENSIVE
  else
    echo 2  # MEDIUM por defecto si no se reconoce
  fi
}

# ── Función: nombre legible del coste ────────────────────────────────────────
cost_name() {
  case "$1" in
    1) echo "CHEAP" ;;
    2) echo "MEDIUM" ;;
    3) echo "EXPENSIVE" ;;
    *) echo "UNKNOWN" ;;
  esac
}

# ── Leer input ───────────────────────────────────────────────────────────────
INPUT_FILE=""
if [[ $# -gt 0 ]]; then
  if [[ -f "$1" ]]; then
    INPUT_FILE="$1"
  else
    echo "ERROR: fichero no encontrado: $1" >&2
    exit 2
  fi
fi

# ── Extraer stages/steps del DAG con Python ──────────────────────────────────
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 requerido" >&2
  exit 2
fi

# Usar Python para parsear YAML/JSON de forma segura
DAG_STEPS=$(python3 - <<'PYTHON_EOF'
import sys
import json

input_lines = sys.stdin.read() if not len(sys.argv) > 1 else open(sys.argv[1]).read()

# Intentar parsear como JSON primero
try:
    data = json.loads(input_lines)
except json.JSONDecodeError:
    # Parseo básico de YAML (sin dependencias externas)
    # Soporta formato: "  - name: foo\n    gate_type: CHEAP"
    data = {}
    current_section = None
    current_item = {}
    items = []
    
    for line in input_lines.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        
        # Detectar sección raíz
        if line and not line.startswith(' ') and not line.startswith('\t'):
            if stripped.endswith(':'):
                if current_item:
                    items.append(current_item)
                    current_item = {}
                key = stripped[:-1]
                current_section = key
                data[key] = []
            continue
        
        # Detectar lista
        if stripped.startswith('- '):
            if current_item:
                items.append(current_item)
                current_item = {}
            value = stripped[2:].strip()
            if ':' in value:
                # key: value
                k, v = value.split(':', 1)
                current_item = {k.strip(): v.strip()}
            else:
                # valor directo
                current_item = {'name': value, '_direct': True}
            if current_section and data.get(current_section) is not None:
                data[current_section].append(current_item if not current_item.get('_direct') else value)
                current_item = {}
        elif ':' in stripped and current_item is not None:
            k, v = stripped.split(':', 1)
            current_item[k.strip()] = v.strip()

# Extraer steps en orden
stages = []

# Formato: stages: [{name:..., gate_type:...}]
for key in ['stages', 'steps', 'pipeline', 'gates']:
    if key in data and data[key]:
        for item in data[key]:
            if isinstance(item, dict):
                stages.append({'name': item.get('name', item.get('id', 'unknown')), 
                               'gate_type': item.get('gate_type', item.get('type', ''))})
            elif isinstance(item, str):
                stages.append({'name': item, 'gate_type': ''})
        break

# Output: una línea por stage: "name|gate_type"
for s in stages:
    print(f"{s['name']}|{s['gate_type']}")

PYTHON_EOF
if [[ -n "$INPUT_FILE" ]]; then
  echo "$INPUT_FILE"
fi
)

# Leer input del stdin o fichero
if [[ -n "$INPUT_FILE" ]]; then
  DAG_STEPS=$(python3 - "$INPUT_FILE" <<'PYTHON_EOF'
import sys
import json

input_lines = open(sys.argv[1]).read()

try:
    data = json.loads(input_lines)
except json.JSONDecodeError:
    data = {}
    current_section = None
    current_item = {}
    items = []
    
    for line in input_lines.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        
        if line and not line.startswith(' ') and not line.startswith('\t'):
            if stripped.endswith(':'):
                if current_item:
                    items.append(current_item)
                    current_item = {}
                key = stripped[:-1]
                current_section = key
                data[key] = []
            continue
        
        if stripped.startswith('- '):
            if current_item:
                items.append(current_item)
                current_item = {}
            value = stripped[2:].strip()
            if ':' in value and not value.startswith('"') and not value.startswith("'"):
                k, v = value.split(':', 1)
                current_item = {k.strip(): v.strip()}
            else:
                current_item = {'name': value.strip('"\''), '_direct': True}
            if current_section and isinstance(data.get(current_section), list):
                if current_item.get('_direct'):
                    data[current_section].append(current_item['name'])
                else:
                    data[current_section].append(dict(current_item))
                current_item = {}
        elif ':' in stripped and current_item is not None:
            k, v = stripped.split(':', 1)
            current_item[k.strip()] = v.strip()

stages = []
for key in ['stages', 'steps', 'pipeline', 'gates']:
    if key in data and data[key]:
        for item in data[key]:
            if isinstance(item, dict):
                stages.append({'name': item.get('name', item.get('id', 'unknown')), 
                               'gate_type': item.get('gate_type', item.get('type', ''))})
            elif isinstance(item, str):
                stages.append({'name': item, 'gate_type': ''})
        break

for s in stages:
    print(f"{s['name']}|{s['gate_type']}")
PYTHON_EOF
)
else
  DAG_STEPS=$(python3 - <<'PYTHON_EOF'
import sys
import json

input_lines = sys.stdin.read()
if not input_lines.strip():
    sys.exit(0)

try:
    data = json.loads(input_lines)
except json.JSONDecodeError:
    data = {}
    current_section = None
    
    for line in input_lines.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        
        if line and not line.startswith(' ') and not line.startswith('\t'):
            if stripped.endswith(':'):
                key = stripped[:-1]
                current_section = key
                data[key] = []
            continue
        
        if stripped.startswith('- '):
            value = stripped[2:].strip()
            if ':' in value and not value.startswith('"') and not value.startswith("'"):
                k, v = value.split(':', 1)
                item = {k.strip(): v.strip()}
            else:
                item = value.strip('"\'')
            if current_section and isinstance(data.get(current_section), list):
                data[current_section].append(item)

stages = []
for key in ['stages', 'steps', 'pipeline', 'gates']:
    if key in data and data[key]:
        for item in data[key]:
            if isinstance(item, dict):
                stages.append({'name': item.get('name', item.get('id', 'unknown')), 
                               'gate_type': item.get('gate_type', item.get('type', ''))})
            elif isinstance(item, str):
                stages.append({'name': item, 'gate_type': ''})
        break

for s in stages:
    print(f"{s['name']}|{s['gate_type']}")
PYTHON_EOF
)
fi

# ── DAG vacío → PASS ─────────────────────────────────────────────────────────
if [[ -z "$DAG_STEPS" ]]; then
  echo "OK: DAG vacío — sin stages que verificar"
  exit 0
fi

# ── Verificar orden de coste ──────────────────────────────────────────────────
VIOLATIONS=()
MAX_COST_SEEN=0
PREV_NAME=""
PREV_COST=0

while IFS='|' read -r step_name gate_type; do
  [[ -z "$step_name" ]] && continue
  
  step_cost=$(get_gate_cost "$step_name" "$gate_type")
  step_type=$(cost_name "$step_cost")
  
  if [[ "$step_cost" -lt "$MAX_COST_SEEN" ]]; then
    VIOLATIONS+=("VIOLATION: '${step_name}' (${step_type}, cost=${step_cost}) aparece después de '${PREV_NAME}' ($(cost_name $PREV_COST), cost=${PREV_COST})")
  fi
  
  if [[ "$step_cost" -gt "$MAX_COST_SEEN" ]]; then
    MAX_COST_SEEN="$step_cost"
  fi
  
  PREV_NAME="$step_name"
  PREV_COST="$step_cost"
  
done <<< "$DAG_STEPS"

# ── Reportar resultado ────────────────────────────────────────────────────────
if [[ ${#VIOLATIONS[@]} -eq 0 ]]; then
  echo "OK: orden coarse-to-fine correcto"
  exit 0
else
  echo "ERROR: ${#VIOLATIONS[@]} violación(es) de orden coarse-to-fine detectada(s):"
  for v in "${VIOLATIONS[@]}"; do
    echo "  - $v"
  done
  echo ""
  echo "Regla: los gates CHEAP deben aparecer antes que MEDIUM, y MEDIUM antes que EXPENSIVE."
  echo "Ref: docs/rules/domain/coarse-to-fine-gates.md"
  exit 1
fi
