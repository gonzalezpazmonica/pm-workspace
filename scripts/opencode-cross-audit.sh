#!/bin/bash
# scripts/opencode-cross-audit.sh
# SPEC-OPC-CROSS-AUDIT — Compara .claude/ vs .opencode/ y detecta drift.
# Recursos comparados: agents (*.md), commands (*.md), skills (*/SKILL.md + */DOMAIN.md)
# Ignora: .opencode/scripts/, .opencode/settings.json
# Modo --fix: copia desde .claude/ → .opencode/ (NUNCA en sentido contrario)
#
# Exit codes: 0=PASS, 1=FAIL (drift/missing), 2=error de uso
set -uo pipefail

# ── Constantes ─────────────────────────────────────────────────────────────────
SCRIPT_NAME="$(basename "$0")"
CLD_ROOT=".claude"
OPC_ROOT=".opencode"
FIX_MODE=false

# ── Colores (desactivar en CI) ─────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; RESET='\033[0m'
else
  RED=''; YELLOW=''; GREEN=''; RESET=''
fi

# ── Uso ────────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--fix] [--help]

Compara .claude/ vs .opencode/ y detecta drift en agents, commands y skills.

Options:
  --fix     Copia recursos con DRIFT o MISSING_OPC desde .claude/ hacia .opencode/
            NUNCA copia en dirección contraria (.opencode/ → .claude/).
  -h, --help  Muestra esta ayuda y sale con código 0.

Exit codes:
  0  PASS — sin drift ni recursos faltantes
  1  FAIL — drift o recursos faltantes detectados
  2  Error de uso (flag desconocido) o entorno inválido
EOF
}

# ── Argumentos ─────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --fix)       FIX_MODE=true ;;
    -h|--help)   usage; exit 0 ;;
    *)
      echo "Error: flag desconocido: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# ── Validar entorno ─────────────────────────────────────────────────────────────
if [[ ! -d "$CLD_ROOT" || ! -d "$OPC_ROOT" ]]; then
  echo "Error: ejecutar desde la raíz del repo (se esperan '$CLD_ROOT/' y '$OPC_ROOT/')" >&2
  exit 2
fi

if ! command -v sha256sum &>/dev/null; then
  echo "Error: sha256sum no disponible" >&2
  exit 2
fi

# ── Helpers ────────────────────────────────────────────────────────────────────
hash_file() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

DRIFT_COUNT=0
MISSING_OPC_COUNT=0
MISSING_CLD_COUNT=0
TOTAL_OK=0

print_header() {
  printf "%-60s %-14s %s\n" "RESOURCE" "STATUS" "DETAIL"
  printf "%-60s %-14s %s\n" "$(printf '%0.s-' {1..60})" "$(printf '%0.s-' {1..14})" "$(printf '%0.s-' {1..40})"
}

report_row() {
  local resource="$1" status="$2" detail="$3"
  case "$status" in
    OK)          color="$GREEN" ;;
    DRIFT)       color="$RED"   ;;
    MISSING_OPC) color="$YELLOW";;
    MISSING_CLD) color="$YELLOW";;
    *)           color=""       ;;
  esac
  printf "${color}%-60s %-14s %s${RESET}\n" "$resource" "$status" "$detail"
}

# ── Función de comparación ─────────────────────────────────────────────────────
# compare_resource <cld_path> <opc_path> <display_name>
compare_resource() {
  local cld="$1" opc="$2" name="$3"
  local cld_exists opc_exists

  [[ -f "$cld" ]] && cld_exists=true || cld_exists=false
  [[ -f "$opc" ]] && opc_exists=true || opc_exists=false

  if $cld_exists && $opc_exists; then
    local h_cld h_opc
    h_cld=$(hash_file "$cld")
    h_opc=$(hash_file "$opc")
    if [[ "$h_cld" == "$h_opc" ]]; then
      report_row "$name" "OK" ""
      (( TOTAL_OK++ )) || true
    else
      report_row "$name" "DRIFT" "sha256 differs (cld=${h_cld:0:8}… opc=${h_opc:0:8}…)"
      (( DRIFT_COUNT++ )) || true
      if $FIX_MODE; then
        mkdir -p "$(dirname "$opc")"
        cp "$cld" "$opc"
        echo "  [fix] $cld → $opc"
      fi
    fi
  elif $cld_exists && ! $opc_exists; then
    report_row "$name" "MISSING_OPC" "existe en .claude/, falta en .opencode/"
    (( MISSING_OPC_COUNT++ )) || true
    if $FIX_MODE; then
      mkdir -p "$(dirname "$opc")"
      cp "$cld" "$opc"
      echo "  [fix] $cld → $opc"
    fi
  elif ! $cld_exists && $opc_exists; then
    report_row "$name" "MISSING_CLD" "existe en .opencode/, falta en .claude/"
    (( MISSING_CLD_COUNT++ )) || true
    # --fix NUNCA copia en sentido .opencode/ → .claude/
  else
    # No existe en ninguno: ignorar (no debería llegar aquí por la lógica de iteración)
    :
  fi
}

# ── Iteración: agents ──────────────────────────────────────────────────────────
print_header

echo ""
echo "## Agents"
echo ""

cld_agents=()
opc_agents=()

while IFS= read -r f; do
  cld_agents+=("$(basename "$f")")
done < <(find "$CLD_ROOT/agents" -maxdepth 1 -name "*.md" 2>/dev/null | sort)

while IFS= read -r f; do
  opc_agents+=("$(basename "$f")")
done < <(find "$OPC_ROOT/agents" -maxdepth 1 -name "*.md" 2>/dev/null | sort)

# Union de nombres
declare -A agent_seen=()
for a in "${cld_agents[@]:-}"; do [[ -n "$a" ]] && agent_seen["$a"]=1; done
for a in "${opc_agents[@]:-}"; do [[ -n "$a" ]] && agent_seen["$a"]=1; done

for name in $(echo "${!agent_seen[@]}" | tr ' ' '\n' | sort); do
  compare_resource "$CLD_ROOT/agents/$name" "$OPC_ROOT/agents/$name" "agents/$name"
done

# ── Iteración: commands ────────────────────────────────────────────────────────
echo ""
echo "## Commands"
echo ""

cld_cmds=()
opc_cmds=()

while IFS= read -r f; do
  cld_cmds+=("$(basename "$f")")
done < <(find "$CLD_ROOT/commands" -maxdepth 1 -name "*.md" 2>/dev/null | sort)

while IFS= read -r f; do
  opc_cmds+=("$(basename "$f")")
done < <(find "$OPC_ROOT/commands" -maxdepth 1 -name "*.md" 2>/dev/null | sort)

declare -A cmd_seen=()
for c in "${cld_cmds[@]:-}"; do [[ -n "$c" ]] && cmd_seen["$c"]=1; done
for c in "${opc_cmds[@]:-}"; do [[ -n "$c" ]] && cmd_seen["$c"]=1; done

for name in $(echo "${!cmd_seen[@]}" | tr ' ' '\n' | sort); do
  compare_resource "$CLD_ROOT/commands/$name" "$OPC_ROOT/commands/$name" "commands/$name"
done

# ── Iteración: skills (*/SKILL.md + */DOMAIN.md) ──────────────────────────────
echo ""
echo "## Skills"
echo ""

cld_skills=()
opc_skills=()

while IFS= read -r d; do
  [[ -d "$d" ]] && cld_skills+=("$(basename "$d")")
done < <(find "$CLD_ROOT/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

while IFS= read -r d; do
  [[ -d "$d" ]] && opc_skills+=("$(basename "$d")")
done < <(find "$OPC_ROOT/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

declare -A skill_seen=()
for s in "${cld_skills[@]:-}"; do [[ -n "$s" ]] && skill_seen["$s"]=1; done
for s in "${opc_skills[@]:-}"; do [[ -n "$s" ]] && skill_seen["$s"]=1; done

for skill in $(echo "${!skill_seen[@]}" | tr ' ' '\n' | sort); do
  for file in SKILL.md DOMAIN.md; do
    cld_path="$CLD_ROOT/skills/$skill/$file"
    opc_path="$OPC_ROOT/skills/$skill/$file"
    # Solo comparar si al menos uno existe
    if [[ -f "$cld_path" || -f "$opc_path" ]]; then
      compare_resource "$cld_path" "$opc_path" "skills/$skill/$file"
    fi
  done
done

# ── Resumen ─────────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────────────────────────"
echo "SUMMARY"
echo "  OK:          $TOTAL_OK"
echo "  DRIFT:       $DRIFT_COUNT"
echo "  MISSING_OPC: $MISSING_OPC_COUNT"
echo "  MISSING_CLD: $MISSING_CLD_COUNT"
echo "────────────────────────────────────────────────────────────────────────────"

FAIL=$(( DRIFT_COUNT + MISSING_OPC_COUNT + MISSING_CLD_COUNT ))

if [[ $FAIL -eq 0 ]]; then
  echo "${GREEN}RESULT: PASS${RESET}"
  exit 0
else
  echo "${RED}RESULT: FAIL — $FAIL issue(s) detected${RESET}"
  exit 1
fi
