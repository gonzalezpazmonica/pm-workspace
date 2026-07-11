#!/usr/bin/env bash
# blast-radius.sh — Calcula el blast radius de un fichero (CodeFlow-inspired)
# Dado un fichero, muestra que otros ficheros dependen de el.
#
# Usage: bash scripts/blast-radius.sh [options] <file> [file2 ...]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults ──
DEPTH=2
FORMAT="table"
USE_MCP=false
USE_GREP=false
FILES=()

# ── Parse args ──
FILES=()

usage() {
  cat <<EOF
Usage: bash scripts/blast-radius.sh [options] <file> [file2 ...]

Calculate the blast radius of files — who depends on this file?

Options:
  --project DIR    Project root directory. Default: current dir
  --depth N        Max dependency depth to trace (1-5). Default: 2
  --format table|json  Output format. Default: table
  --mcp            Force MCP trace via codebase-memory-mcp
  --grep           Force grep-based fallback

Examples:
  blast-radius.sh src/main.sh
  blast-radius.sh --depth 3 --json src/utils.sh
  blast-radius.sh --project ~/myproject src/app.ts
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) ROOT="$2"; shift 2 ;;
    --depth) DEPTH="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --mcp) USE_MCP=true; shift ;;
    --grep) USE_GREP=true; shift ;;
    --help|-h) usage; exit 0 ;;
    --) shift; FILES+=("$@"); break ;;
    -*) echo "ERROR: unknown option: $1" >&2; exit 1 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

# ── Validate inputs ──
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "ERROR: at least one file required" >&2
  usage >&2
  exit 1
fi

if ! [[ "$DEPTH" =~ ^[1-5]$ ]]; then
  echo "ERROR: depth must be 1-5, got '$DEPTH'" >&2
  exit 1
fi

if [[ "$FORMAT" != "table" && "$FORMAT" != "json" ]]; then
  echo "ERROR: format must be table or json, got '$FORMAT'" >&2
  exit 1
fi

# ── Risk classification ──
risk_level() {
  local d=$1
  if [[ "$d" -eq 1 ]]; then echo "HIGH"
  elif [[ "$d" -eq 2 ]]; then echo "MEDIUM"
  else echo "LOW"
  fi
}

risk_weight() {
  local d=$1
  if [[ "$d" -eq 1 ]]; then echo 10
  elif [[ "$d" -eq 2 ]]; then echo 6
  else echo 3
  fi
}

# ── Grep-based dependency scanner ──
scan_deps() {
  local target="$1" max_depth="$2"
  local -A seen
  seen["$target"]=1
  local queue=("$target:1")
  local results=()

  while [[ ${#queue[@]} -gt 0 ]]; do
    local entry="${queue[0]}"
    queue=("${queue[@]:1}")
    local current="${entry%%:*}"
    local cdepth="${entry##*:}"

    [[ "$cdepth" -gt "$max_depth" ]] && continue

    local basename
    basename=$(basename "$current" | sed 's/\.[^.]*$//')

    # Search for references to this file's basename in other files
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      # Skip self-reference and already seen
      local ref_clean="${ref#./}"
      [[ "$ref_clean" == "$current" ]] && continue
      [[ -n "${seen[$ref_clean]:-}" ]] && continue

      seen["$ref_clean"]=1

      # Determine relation type
      local rel="imports"
      local content
      content=$(cat "$ref_clean" 2>/dev/null || true)
      if echo "$content" | grep -qE "(source|\.) \.*${basename}"; then
        rel="imports"
      elif echo "$content" | grep -qE "(require|import).*${basename}"; then
        rel="imports"
      else
        rel="references"
      fi

      results+=("$ref_clean|$cdepth|$(risk_level "$cdepth")|$rel")
      queue+=("$ref_clean:$((cdepth + 1))")
    done < <(grep -rl "$basename" "$ROOT" \
      --include="*.sh" --include="*.ts" --include="*.js" --include="*.py" \
      --include="*.go" --include="*.rb" --include="*.rs" --include="*.cs" \
      --include="*.md" --include="*.yml" --include="*.yaml" \
      2>/dev/null | grep -v "^$ROOT/$current$" | sed "s|^$ROOT/||")

    [[ ${#queue[@]} -gt 50 ]] && break
  done

  printf '%s\n' "${results[@]}"
}

# ── Calculate risk score ──
calc_risk_score() {
  local results=("$@")
  local score=0 max_score=0
  for r in "${results[@]}"; do
    [[ -z "$r" ]] && continue
    local depth="${r#*|}"; depth="${depth%%|*}"
    score=$((score + $(risk_weight "$depth")))
    max_score=$((max_score + 10))
  done
  if [[ "$max_score" -eq 0 ]]; then echo 0; return; fi
  echo $(( (score * 100) / max_score ))
  [[ $(( (score * 100) / max_score )) -gt 100 ]] && echo 100
}

risk_grade() {
  local s=$1
  if [[ "$s" -le 20 ]]; then echo "LOW"
  elif [[ "$s" -le 50 ]]; then echo "MEDIUM"
  elif [[ "$s" -le 80 ]]; then echo "HIGH"
  else echo "CRITICAL"
  fi
}

# ── Main ──
all_results=()
exit_code=0

for target_file in "${FILES[@]}"; do
  # Normalize path
  target_file="${target_file#./}"
  [[ "$target_file" == /* ]] || target_file="$ROOT/$target_file"
  target_file="${target_file#$ROOT/}"

  if [[ ! -f "$ROOT/$target_file" ]]; then
    echo "ERROR: file not found: $target_file" >&2
    exit_code=1
    continue
  fi

  # Scan dependencies
  mapfile -t results < <(scan_deps "$target_file" "$DEPTH")

  if [[ "$FORMAT" == "json" ]]; then
    direct=0 transitive=0
    for r in "${results[@]}"; do
      [[ -z "$r" ]] && continue
      d="${r#*|}"; d="${d%%|*}"
      [[ "$d" -eq 1 ]] && direct=$((direct + 1))
      [[ "$d" -gt 1 ]] && transitive=$((transitive + 1))
    done
    rscore=$(calc_risk_score "${results[@]}")

    impacted_json="["
    first=true
    for r in "${results[@]}"; do
      [[ -z "$r" ]] && continue
      IFS='|' read -r file depth risk rel <<< "$r"
      $first || impacted_json+=","
      first=false
      impacted_json+="{\"file\":\"$file\",\"depth\":$depth,\"risk\":\"$risk\",\"relation\":\"$rel\"}"
    done
    impacted_json+="]"

    cat <<JSON
{
  "file": "$target_file",
  "depth": $DEPTH,
  "total_impacted": ${#results[@]},
  "direct": $direct,
  "transitive": $transitive,
  "risk_score": $rscore,
  "risk_level": "$(risk_grade $rscore)",
  "impacted": $impacted_json
}
JSON
  else
    # Table format
    echo "╔══════════════════════════════════════════════════════════════════╗"
    printf "║  Blast Radius: %-50s ║\n" "$target_file"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    printf "║  %-4s  %-42s %-6s  %-10s ║\n" "D=N" "File" "Risk" "Relation"
    echo "╠══════════════════════════════════════════════════════════════════╣"

    if [[ ${#results[@]} -eq 0 ]]; then
      echo "║  No dependents found                                           ║"
    else
      for r in "${results[@]}"; do
        [[ -z "$r" ]] && continue
        IFS='|' read -r file depth risk rel <<< "$r"
        printf "║  D=%-2s  %-42s %-6s  %-10s ║\n" "$depth" "${file:0:42}" "$risk" "$rel"
      done
    fi

    rscore=$(calc_risk_score "${results[@]}")
    direct=0 transitive=0
    for r in "${results[@]}"; do
      [[ -z "$r" ]] && continue
      d="${r#*|}"; d="${d%%|*}"
      [[ "$d" -eq 1 ]] && direct=$((direct + 1))
      [[ "$d" -gt 1 ]] && transitive=$((transitive + 1))
    done

    echo "╠══════════════════════════════════════════════════════════════════╣"
    printf "║  Summary: %d files impacted, %d direct, %d transitive             ║\n" \
      "${#results[@]}" "$direct" "$transitive"
    printf "║  Risk score: %s/100 (%-8s)                              ║\n" \
      "$rscore" "$(risk_grade "$rscore")" " "
    echo "╚══════════════════════════════════════════════════════════════════╝"
  fi

  all_results+=("${results[@]}")
done

exit $exit_code
