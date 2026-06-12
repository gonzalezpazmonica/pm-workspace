#!/usr/bin/env bash
set -uo pipefail
# context-capability-check.sh — SE-221 Slice 3 — Capability metadata validator
# Valida que el frontmatter `audience:` (opcional) en docs/skills/agents
# es sintacticamente valido y referencia agentes existentes.
#
# Spec: docs/propuestas/SE-221-inverted-security-patterns-as-context-engineering.md (AC-13)
# Inspiracion: CaMeL (Debenedetti et al. 2025) — capabilities estaticas.
#
# Reglas:
#   - audience puede faltar (default implicito = all-agents).
#   - audience puede ser:
#       * lista YAML: ["agent1", "agent2"] o - agent1\n- agent2
#       * string canonico: "all-agents" o "humans-only"
#       * lista mixta: ["all-agents", "agent1"] (extiende sin restringir)
#   - cada agente referenciado debe existir en .opencode/agents/{name}.md
#     o ser palabra reservada all-agents/humans-only.
#
# Uso:
#   scripts/context-capability-check.sh [--paths PATH1 PATH2 ...] [--json] [--strict]
#   Sin --paths: escanea docs/rules/domain/ y .opencode/skills/*/SKILL.md
#
# Exit codes:
#   0 — todos OK
#   1 — al menos un fichero invalido
#   2 — args invalidos

JSON=0
STRICT=0
PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --strict) STRICT=1; shift ;;
    --paths)
      shift
      while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
        PATHS+=("$1"); shift
      done
      ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${SAVIA_WORKSPACE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
AGENTS_DIR="${SAVIA_AGENTS_DIR:-$WORKSPACE/.opencode/agents}"

# Construir set de agentes validos
declare -A VALID_AGENTS
if [[ -d "$AGENTS_DIR" ]]; then
  while IFS= read -r f; do
    name=$(basename "$f" .md)
    VALID_AGENTS["$name"]=1
  done < <(find "$AGENTS_DIR" -maxdepth 1 -name '*.md' -type f 2>/dev/null)
fi
# Reservadas
VALID_AGENTS["all-agents"]=1
VALID_AGENTS["humans-only"]=1

# Default scan paths
if [[ ${#PATHS[@]} -eq 0 ]]; then
  while IFS= read -r f; do
    PATHS+=("$f")
  done < <(find "$WORKSPACE/docs/rules/domain" -name '*.md' -type f 2>/dev/null; \
           find "$WORKSPACE/.opencode/skills" -name 'SKILL.md' -type f 2>/dev/null)
fi

# Helper: extrae bloque YAML audience: del frontmatter
extract_audience() {
  local file="$1"
  python3 - "$file" <<'PY' 2>/dev/null
import sys
import re
p = sys.argv[1]
try:
    with open(p, 'r', encoding='utf-8') as fh:
        text = fh.read()
except Exception:
    sys.exit(0)

# Frontmatter entre --- al inicio
m = re.match(r'^---\s*\n(.*?)\n---\s*\n', text, re.DOTALL)
if not m:
    sys.exit(0)
fm = m.group(1)

# Extrae audience: <value> con captura de bloque multilinea
lines = fm.splitlines()
out = []
i = 0
while i < len(lines):
    line = lines[i]
    am = re.match(r'^audience:\s*(.*)$', line)
    if am:
        inline = am.group(1).strip()
        if inline.startswith('['):
            # Lista inline ["a", "b"] o [a, b]
            content = inline.strip('[]')
            for part in content.split(','):
                v = part.strip().strip('"').strip("'")
                if v:
                    out.append(v)
        elif inline:
            # String simple
            out.append(inline.strip('"').strip("'"))
        else:
            # Lista multilinea: leer lineas siguientes con `  - x`
            j = i + 1
            while j < len(lines):
                ml = re.match(r'^\s*-\s*(.+)$', lines[j])
                if ml:
                    v = ml.group(1).strip().strip('"').strip("'")
                    if v:
                        out.append(v)
                    j += 1
                elif re.match(r'^\s*$', lines[j]) or re.match(r'^\s+', lines[j]):
                    j += 1
                    if not re.match(r'^\s*-\s+', lines[j-1]) and re.match(r'^\S', lines[j]) if j < len(lines) else True:
                        break
                else:
                    break
            i = j - 1
        break
    i += 1

for o in out:
    print(o)
PY
}

ERRORS=0
RESULTS=()

validate_file() {
  local file="$1"
  local audience_list
  audience_list=$(extract_audience "$file")
  # Sin audience: ok (default implicito)
  if [[ -z "$audience_list" ]]; then
    if [[ "$STRICT" -eq 1 ]]; then
      RESULTS+=("MISSING|$file|audience field absent (strict mode)")
      ERRORS=$((ERRORS+1))
      return
    else
      RESULTS+=("OK_DEFAULT|$file|implicit all-agents")
      return
    fi
  fi
  # Validar cada item
  local invalids=()
  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    if [[ -z "${VALID_AGENTS[$item]:-}" ]]; then
      invalids+=("$item")
    fi
  done <<< "$audience_list"

  if [[ ${#invalids[@]} -gt 0 ]]; then
    local joined
    joined=$(IFS=,; echo "${invalids[*]}")
    RESULTS+=("INVALID|$file|unknown agents: $joined")
    ERRORS=$((ERRORS+1))
  else
    local n_items
    n_items=$(echo "$audience_list" | wc -l | tr -d ' ')
    RESULTS+=("OK|$file|$n_items targets")
  fi
}

for f in "${PATHS[@]}"; do
  validate_file "$f"
done

# Output
if [[ "$JSON" -eq 1 ]]; then
  printf '{"errors":%d,"total":%d,"results":[' "$ERRORS" "${#RESULTS[@]}"
  first=1
  for r in "${RESULTS[@]}"; do
    [[ $first -eq 0 ]] && printf ','
    first=0
    status="${r%%|*}"
    rest="${r#*|}"
    file="${rest%%|*}"
    msg="${rest#*|}"
    msg_esc=$(printf '%s' "$msg" | python3 -c 'import sys,json;print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$msg")
    printf '{"status":"%s","file":"%s","msg":%s}' "$status" "$file" "$msg_esc"
  done
  printf ']}\n'
else
  for r in "${RESULTS[@]}"; do
    status="${r%%|*}"
    rest="${r#*|}"
    file="${rest%%|*}"
    msg="${rest#*|}"
    case "$status" in
      INVALID|MISSING) echo "FAIL [$status] $file — $msg" >&2 ;;
      OK|OK_DEFAULT) [[ "${VERBOSE:-0}" -eq 1 ]] && echo "ok   [$status] $file — $msg" ;;
    esac
  done
  if [[ "$ERRORS" -gt 0 ]]; then
    echo "$ERRORS error(s) en ${#RESULTS[@]} ficheros" >&2
  fi
fi

exit $(( ERRORS > 0 ? 1 : 0 ))
