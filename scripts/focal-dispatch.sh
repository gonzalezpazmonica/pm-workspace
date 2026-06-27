#!/usr/bin/env bash
# focal-dispatch.sh — Prioriza y presenta la decisión humana más crítica (SE-230 Slice 2)
# Usage: focal-dispatch.sh [--all-blocking] [--all]
set -uo pipefail

SAVIA_DIR="${HOME}/.savia"
FOCAL_DIR="${SAVIA_DIR}/focal-state"

mkdir -p "$FOCAL_DIR"

ALL_BLOCKING=0
SHOW_ALL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all-blocking) ALL_BLOCKING=1; shift ;;
    --all)          SHOW_ALL=1;     shift ;;
    *)              shift ;;
  esac
done

_now_epoch() { date +%s; }
_iso_to_epoch() {
  local iso="$1"
  date -d "$iso" +%s 2>/dev/null && return
  date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null || echo 0
}
_json_field() {
  local json="$1" key="$2"
  local flat
  flat=$(printf '%s' "$json" | tr -d '\n' | tr -s ' ')
  local val
  val=$(printf '%s' "$flat" | grep -oP "\"${key}\"\\s*:\\s*\"\\K[^\"]*" 2>/dev/null || true)
  if [[ -z "$val" ]]; then
    val=$(printf '%s' "$flat" | grep -oP "\"${key}\"\\s*:\\s*\\K(true|false|null|[0-9]+)" 2>/dev/null || true)
  fi
  printf '%s' "$val"
}
_json_nested() {
  local json="$1" key="$2"
  local flat
  flat=$(printf '%s' "$json" | tr -d '\n' | tr -s ' ')
  local block
  block=$(printf '%s' "$flat" | grep -oP '"next_human_decision"\s*:\s*\{[^}]*\}' 2>/dev/null || true)
  [[ -z "$block" ]] && return
  _json_field "$block" "$key"
}

now_epoch=$(_now_epoch)

# ── Recopilar decisiones ───────────────────────────────────────────────────────
ENTRIES=()  # "priority|nido|type|description|blocking|urgency|cost|age_min"

for f in "${FOCAL_DIR}"/*.json; do
  [[ -f "$f" ]] || continue
  json=$(cat "$f" 2>/dev/null) || continue
  [[ -z "$json" ]] && continue

  # Validar JSON básicamente
  if ! printf '%s' "$json" | grep -q '"nido"'; then continue; fi

  nido=$(_json_field "$json" "nido")
  [[ -z "$nido" ]] && nido=$(basename "$f" .json)

  status=$(_json_field "$json" "status")
  [[ "$status" == "done" || "$status" == "abandoned" ]] && continue

  nhd_desc=$(_json_nested "$json" "description")
  [[ -z "$nhd_desc" ]] && continue
  # next_human_decision: null check
  local flat_json; flat_json=$(printf '%s' "$json" | tr -d '\n' | tr -s ' ')
  nhd_raw=$(printf '%s' "$flat_json" | grep -oP '"next_human_decision"\s*:\s*null' 2>/dev/null || true)
  [[ -n "$nhd_raw" ]] && continue

  nhd_block=$(_json_nested "$json" "blocking")
  nhd_urgency=$(_json_nested "$json" "urgency")
  [[ -z "$nhd_urgency" ]] && nhd_urgency=0
  nhd_cost=$(_json_nested "$json" "cognitive_cost")
  [[ -z "$nhd_cost" ]] && nhd_cost=2
  nhd_type=$(_json_nested "$json" "type")
  nhd_created=$(_json_nested "$json" "created_at")

  blocking_int=0
  [[ "$nhd_block" == "true" ]] && blocking_int=1

  # Filtro --all-blocking
  if [[ $ALL_BLOCKING -eq 1 && "$nhd_block" != "true" ]]; then continue; fi

  # age_min
  age_min=0
  if [[ -n "$nhd_created" ]]; then
    nhd_epoch=$(_iso_to_epoch "$nhd_created")
    age_min=$(( (now_epoch - nhd_epoch) / 60 ))
    [[ $age_min -lt 0 ]] && age_min=0
  fi

  # priority = max(0, urgency*3 + blocking*5 + age_min*0.1 - cognitive_cost*2)
  priority=$(awk -v u="$nhd_urgency" -v b="$blocking_int" -v a="$age_min" -v c="$nhd_cost" \
    'BEGIN { p = (u*3) + (b*5) + (a*0.1) - (c*2); if (p<0) p=0; printf "%.2f", p }')

  ENTRIES+=("${priority}|${nido}|${nhd_type}|${nhd_desc}|${nhd_block}|${nhd_urgency}|${nhd_cost}|${age_min}")
done

if [[ ${#ENTRIES[@]} -eq 0 ]]; then
  echo "Sin decisiones pendientes"
  exit 0
fi

# ── Ordenar por prioridad desc ────────────────────────────────────────────────
IFS=$'\n' sorted=($(printf '%s\n' "${ENTRIES[@]}" | sort -t'|' -k1 -rn))
unset IFS

# ── Mostrar ────────────────────────────────────────────────────────────────────
_print_entry() {
  local entry="$1" idx="$2"
  IFS='|' read -r priority nido_n type desc blocking urgency cost age <<< "$entry"
  local label="[URGENT]"
  [[ "$blocking" == "true" ]] && label="[BLOCKING]"
  printf '  [%d] %s: %s %s\n' "$idx" "$nido_n" "$desc" "$label"
  printf '      tipo:%s urgency:%s cost:%s age:%smin prioridad:%.2f\n' \
    "$type" "$urgency" "$cost" "$age" "$priority"
}

if [[ $SHOW_ALL -eq 1 || $ALL_BLOCKING -eq 1 ]]; then
  idx=1
  for entry in "${sorted[@]}"; do
    _print_entry "$entry" "$idx"
    (( idx++ )) || true
  done
else
  # Solo la más crítica
  echo "SIGUIENTE DECISIÓN CRÍTICA:"
  _print_entry "${sorted[0]}" 1
  remaining=$(( ${#sorted[@]} - 1 ))
  if [[ $remaining -gt 0 ]]; then
    echo ""
    echo "  (${remaining} decisiones adicionales — usa --all para ver todas)"
  fi
fi

exit 0
