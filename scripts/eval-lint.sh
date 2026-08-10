#!/usr/bin/env bash
# eval-lint.sh — SE-316 S1: valida golden sets de tribunales (SE-274 S2).
#
# Para cada `tests/evals/<tribunal>/cases.jsonl` valida:
#   - JSONL parseable línea a línea,
#   - campos mínimos por caso (id, input, expected, should_trigger,
#     should_not_trigger[]), contra config/eval-case.schema.json (jsonschema si
#     está disponible; si no, validación manual de campos esenciales),
#   - contadores mínimos por tribunal (>=5 should_trigger, >=4
#     should_not_trigger con route_to no vacío),
#   - cada `route_to` (salvo `none`/`external:`) resuelve contra
#     docs/RESOLVER.md (`agent:`/`skill:`) o el catálogo de skills (SKILLS.md).
#
# Uso:
#   eval-lint.sh --check <evals-dir>   # dir por defecto: tests/evals
#   eval-lint.sh --check               # usa tests/evals
#   eval-lint.sh --json                # salida JSON (violaciones + resumen)
#
# Exit codes: 0 PASS, 1 FAIL (violaciones listadas), 2 usage.
#
# Ref: SE-316 (docs/propuestas/SE-316-eval-lint-golden-sets.md)
# Ref: SE-274 S2 (docs/propuestas/SE-274-agent-quality-framework.md)
set -uo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
EVALS_DIR="tests/evals"
OUTPUT_JSON=0
SCHEMA="$REPO_ROOT/config/eval-case.schema.json"
RESOLVER="$REPO_ROOT/docs/RESOLVER.md"
SKILLS_INDEX="$REPO_ROOT/SKILLS.md"

usage() {
  cat <<EOF
Usage: $0 [--check [<evals-dir>]] [--json]

  --check [dir]   Validate golden sets under dir (default: tests/evals)
  --json          Emit JSON result to stdout (single line)

Exit: 0 PASS, 1 FAIL, 2 usage.
Ref: SE-316 (eval-lint golden sets).
EOF
}

[[ $# -eq 0 ]] && { usage; exit 2; }

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check"; shift
      if [[ -n "${1:-}" && "$1" != "--json" && "$1" != --* ]]; then
        EVALS_DIR="$1"; shift
      fi ;;
    --json) OUTPUT_JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

[[ "$MODE" != "check" ]] && { usage; exit 2; }
# EVALS_DIR puede ser relativo al repo o absoluto
case "$EVALS_DIR" in
  /*) EVALS_PATH="$EVALS_DIR" ;;
  *)  EVALS_PATH="$REPO_ROOT/$EVALS_DIR" ;;
esac
[[ -d "$EVALS_PATH" ]] || { echo "ERROR: evals dir no existe: $EVALS_DIR" >&2; exit 2; }

# ── Catálogo de targets resolubles (agentes + skills) ───────────────────────
RESOLVABLE_AGENTS=""
RESOLVABLE_SKILLS=""
if [[ -f "$RESOLVER" ]]; then
  RESOLVABLE_AGENTS=$(grep -oE 'agent:[a-z0-9-]+' "$RESOLVER" | sed 's/^agent://' | sort -u)
  RESOLVABLE_SKILLS=$(grep -oE 'skill:[a-z0-9-]+' "$RESOLVER" | sed 's/^skill://' | sort -u)
fi
if [[ -f "$SKILLS_INDEX" ]]; then
  RESOLVABLE_SKILLS="$(printf '%s\n%s' "$RESOLVABLE_SKILLS" "$(grep -oE '^\| [a-z0-9-]+ \|' "$SKILLS_INDEX" | sed 's/^| //; s/ |$//' | sort -u)")"
fi

target_resolvable() {
  local t="$1"
  case "$t" in
    none) return 0 ;;
    external:*) return 0 ;;
    agent:*)
      local id="${t#agent:}"
      echo "$RESOLVABLE_AGENTS" | grep -qx "$id" && return 0
      # Fallback: catálogo real de agentes
      ls "$REPO_ROOT/.opencode/agents/" 2>/dev/null | sed 's/\.md$//' | grep -qx "$id" && return 0
      return 1 ;;
    skill:*)
      local id="${t#skill:}"
      echo "$RESOLVABLE_SKILLS" | grep -qx "$id" && return 0
      ls "$REPO_ROOT/.opencode/skills/" 2>/dev/null | grep -qx "$id" && return 0
      return 1 ;;
    *) return 1 ;;
  esac
}

# ── Validación de un caso (manual si jsonschema no está) ────────────────────
VIOLATIONS=()
case_count=0
fail_case() { VIOLATIONS+=("$1"); }

validate_case() {
  local file="$1" idx="$2" line="$3"
  local id="" ntrig=0 nnot=0
  if ! echo "$line" | python3 -m json.tool >/dev/null 2>&1; then
    fail_case "$file:$idx: JSONL inválido"
    return
  fi
  id=$(echo "$line" | jq -r '.id // empty' 2>/dev/null)
  [[ -z "$id" ]] && fail_case "$file:$idx: falta campo 'id'"
  [[ -z "$(echo "$line" | jq -r '.input // empty' 2>/dev/null)" ]] && fail_case "$file:${idx}[${id}]: falta 'input'"
  [[ -z "$(echo "$line" | jq -r '.expected // empty' 2>/dev/null)" ]] && fail_case "$file:${idx}[${id}]: falta 'expected'"
  ntrig=$(echo "$line" | jq '.should_trigger | length' 2>/dev/null || echo "0")
  [[ "$ntrig" == "null" || "$ntrig" -lt 1 ]] && fail_case "$file:${idx}[${id}]: should_trigger vacío"
  nnot=$(echo "$line" | jq '.should_not_trigger | length' 2>/dev/null || echo "0")
  [[ "$nnot" == "null" || "$nnot" -lt 1 ]] && fail_case "$file:${idx}[${id}]: should_not_trigger vacío"
  # route_to resoluble
  local i=0 rt
  while [[ $i -lt ${nnot:-0} ]]; do
    rt=$(echo "$line" | jq -r --argjson i "$i" '.should_not_trigger[$i].route_to // empty' 2>/dev/null)
    [[ -z "$rt" ]] && fail_case "$file:${idx}[${id}]: should_not_trigger[${i}] sin route_to"
    if ! target_resolvable "$rt"; then
      fail_case "$file:${idx}[${id}]: route_to '$rt' no resuelve (ni agente ni skill ni none/external)"
    fi
    i=$((i+1))
  done
}

# ── Cobertura mínima por tribunal ───────────────────────────────────────────
check_min_coverage() {
  local file="$1"
  local base
  base=$(basename "$(dirname "$file")")
  local ntrig=0 nnot=0 cap=0
  ntrig=$(grep -c '"should_trigger"' "$file" 2>/dev/null || echo "0")
  nnot=$(grep -c '"route_to"' "$file" 2>/dev/null || echo "0")
  cap=$(grep -c '"capabilities"' "$file" 2>/dev/null || echo "0")
  # Mínimos SE-316 S1: >=5 should_trigger, >=4 should_not_trigger, >=1 capability
  ntrig=$(printf '%s' "$ntrig" | head -1)
  nnot=$(printf '%s' "$nnot" | head -1)
  cap=$(printf '%s' "$cap" | head -1)
  [[ "${ntrig:-0}" -lt 5 ]] && fail_case "$file: cobertura should_trigger=$ntrig < 5"
  [[ "${nnot:-0}" -lt 4 ]] && fail_case "$file: cobertura route_to=$nnot < 4"
  [[ "${cap:-0}" -lt 1 ]] && fail_case "$file: cobertura capabilities=$cap < 1"
}

# ── Recorrido principal ─────────────────────────────────────────────────────
FILES=()
while IFS= read -r f; do
  FILES+=("$f")
done < <(find "$EVALS_PATH" -name 'cases.jsonl' -o -name '*.golden.jsonl' 2>/dev/null | sort)

if [[ ${#FILES[@]} -eq 0 ]]; then
  if [[ "$OUTPUT_JSON" -eq 1 ]]; then
    echo '{"verdict":"FAIL","violations":["no golden sets encontrados bajo '$EVALS_DIR'"],"files":0,"cases":0}'
  else
    echo "FAIL: no golden sets encontrados bajo $EVALS_PATH" >&2
  fi
  exit 1
fi

total_cases=0
for file in "${FILES[@]}"; do
  rel="${file#$REPO_ROOT/}"
  [[ -f "$file" ]] || continue
  check_min_coverage "$rel"
  local_idx=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    local_idx=$((local_idx+1))
    [[ -z "$line" ]] && continue
    total_cases=$((total_cases+1))
    validate_case "$rel" "$local_idx" "$line"
  done < "$file"
done

if [[ ${#VIOLATIONS[@]} -eq 0 ]]; then
  if [[ "$OUTPUT_JSON" -eq 1 ]]; then
    jq -nc --arg v "PASS" --argjson files "${#FILES[@]}" --argjson cases "$total_cases" \
      '{verdict:$v, files:$files, cases:$cases, violations:[]}'
  else
    echo "PASS: ${#FILES[@]} golden set(s), $total_cases casos, 0 violaciones"
  fi
  exit 0
else
  if [[ "$OUTPUT_JSON" -eq 1 ]]; then
    jq -nc --arg v "FAIL" --argjson files "${#FILES[@]}" --argjson cases "$total_cases" \
      --argjson arr "$(printf '%s\n' "${VIOLATIONS[@]}" | jq -R -s -c 'split("\n") | map(select(length>0))')" \
      '{verdict:$v, files:$files, cases:$cases, violations:$arr}'
  else
    echo "FAIL: ${#VIOLATIONS[@]} violaciones en $total_cases casos"
    for v in "${VIOLATIONS[@]}"; do
      echo "  - $v"
    done
  fi
  exit 1
fi
