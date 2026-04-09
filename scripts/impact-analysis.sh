#!/usr/bin/env bash
set -uo pipefail
# impact-analysis.sh — Analyze codebase impact of modifying files
# Usage: bash scripts/impact-analysis.sh [options] <file1> [file2] [...]
#
# Options:
#   --project DIR          Project root directory. Default: current dir
#   --depth N              Max dependency depth to trace. Default: 2
#   --include-tests        Include test files in impact graph. Default: true
#   --format compact|full  Output detail level. Default: compact
#   --output FILE          Write report to file. Default: stdout
#
# Exit: 0 success, 1 error

# ── Defaults ──────────────────────────────────────────────────────────────────
PROJECT_DIR="."
MAX_DEPTH=2
INCLUDE_TESTS=true
OUTPUT_FORMAT="compact"
OUTPUT_FILE=""
TARGET_FILES=()

# ── Excluded directories ──────────────────────────────────────────────────────
EXCLUDE_DIRS="node_modules|vendor|\.git|__pycache__|\.venv|dist|build|\.next|target"

# ── Argument parsing ──────────────────────────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)
        [[ $# -lt 2 ]] && { echo "Error: --project requires a directory" >&2; exit 1; }
        PROJECT_DIR="$2"; shift 2 ;;
      --depth)
        [[ $# -lt 2 ]] && { echo "Error: --depth requires a number" >&2; exit 1; }
        MAX_DEPTH="$2"; shift 2 ;;
      --include-tests)
        INCLUDE_TESTS=true; shift ;;
      --no-include-tests)
        INCLUDE_TESTS=false; shift ;;
      --format)
        [[ $# -lt 2 ]] && { echo "Error: --format requires compact|full" >&2; exit 1; }
        OUTPUT_FORMAT="$2"; shift 2 ;;
      --output)
        [[ $# -lt 2 ]] && { echo "Error: --output requires a file path" >&2; exit 1; }
        OUTPUT_FILE="$2"; shift 2 ;;
      -*)
        echo "Error: unknown option $1" >&2; exit 1 ;;
      *)
        TARGET_FILES+=("$1"); shift ;;
    esac
  done
}

# ── Validate inputs ──────────────────────────────────────────────────────────
validate_inputs() {
  if [[ ${#TARGET_FILES[@]} -eq 0 ]]; then
    echo "Error: no target files specified" >&2
    echo "Usage: bash scripts/impact-analysis.sh [options] <file1> [file2] [...]" >&2
    exit 1
  fi

  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: project directory does not exist: $PROJECT_DIR" >&2
    exit 1
  fi

  if [[ "$MAX_DEPTH" -lt 1 || "$MAX_DEPTH" -gt 3 ]]; then
    echo "Error: depth must be 1-3, got $MAX_DEPTH" >&2
    exit 1
  fi

  if [[ "$OUTPUT_FORMAT" != "compact" && "$OUTPUT_FORMAT" != "full" ]]; then
    echo "Error: format must be compact|full, got $OUTPUT_FORMAT" >&2
    exit 1
  fi
}

# ── Language detection ────────────────────────────────────────────────────────
detect_language() {
  local file="$1"
  case "$file" in
    *.ts|*.tsx|*.mts|*.cts)   echo "typescript" ;;
    *.js|*.jsx|*.mjs|*.cjs)   echo "javascript" ;;
    *.cs)                      echo "csharp" ;;
    *.py)                      echo "python" ;;
    *.go)                      echo "go" ;;
    *.rs)                      echo "rust" ;;
    *.java)                    echo "java" ;;
    *.rb)                      echo "ruby" ;;
    *.php)                     echo "php" ;;
    *)                         echo "unknown" ;;
  esac
}

# ── Extract module name from file path ────────────────────────────────────────
extract_module_name() {
  local file="$1"
  local basename
  basename=$(basename "$file")
  # Strip extension and common suffixes
  basename="${basename%.*}"
  basename="${basename%.spec}"
  basename="${basename%.test}"
  basename="${basename%.tests}"
  echo "$basename"
}

# ── Build grep pattern for imports of a module ────────────────────────────────
build_import_pattern() {
  local module_name="$1"
  local lang="$2"
  local file_path="$3"

  # Escape special regex chars in module name
  local escaped
  escaped=$(printf '%s' "$module_name" | sed 's/[.[\*^$()+?{|\\]/\\&/g')

  # Build a broad pattern that catches imports across languages
  local patterns=()

  case "$lang" in
    typescript|javascript)
      patterns+=("import .* from .*['\"/]${escaped}['\"]")
      patterns+=("require\\(['\"].*${escaped}['\"]\\)")
      patterns+=("from ['\"].*${escaped}['\"]")
      ;;
    csharp)
      # Extract namespace-like path
      local ns_part
      ns_part=$(dirname "$file_path" | tr '/' '.' | sed 's/^\.//')
      patterns+=("using .*${escaped}")
      if [[ -n "$ns_part" && "$ns_part" != "." ]]; then
        patterns+=("using .*${ns_part}")
      fi
      ;;
    python)
      patterns+=("from .*${escaped}.* import")
      patterns+=("import .*${escaped}")
      ;;
    go)
      patterns+=("\".*${escaped}\"")
      ;;
    rust)
      patterns+=("use .*${escaped}")
      patterns+=("mod ${escaped}")
      ;;
    java)
      patterns+=("import .*\\.${escaped}")
      ;;
    *)
      # Generic fallback: look for the module name in import-like lines
      patterns+=("import.*${escaped}")
      patterns+=("require.*${escaped}")
      patterns+=("from.*${escaped}")
      patterns+=("use .*${escaped}")
      ;;
  esac

  # Combine patterns with OR
  local combined=""
  for p in "${patterns[@]}"; do
    if [[ -n "$combined" ]]; then
      combined="${combined}|${p}"
    else
      combined="$p"
    fi
  done
  echo "$combined"
}

# ── Find files that import a given module ─────────────────────────────────────
find_dependents() {
  local file_path="$1"
  local lang="$2"
  local module_name
  module_name=$(extract_module_name "$file_path")
  local pattern
  pattern=$(build_import_pattern "$module_name" "$lang" "$file_path")

  if [[ -z "$pattern" ]]; then
    return
  fi

  # Resolve the file to absolute for exclusion
  local abs_file
  abs_file=$(resolve_file "$file_path")

  # Grep recursively, excluding known dirs and the file itself
  grep -rlE "$pattern" "$PROJECT_DIR" \
    --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
    --include='*.cs' --include='*.py' --include='*.go' --include='*.rs' \
    --include='*.java' --include='*.rb' --include='*.php' \
    --include='*.mts' --include='*.cts' --include='*.mjs' --include='*.cjs' \
    2>/dev/null \
    | grep -vE "(${EXCLUDE_DIRS})" \
    | grep -v -F "$abs_file" \
    | sort -u || true
}

# ── Check if a file is a test file ────────────────────────────────────────────
is_test_file() {
  local file="$1"
  case "$file" in
    *test*|*spec*|*Test*|*Spec*|*_test.*|*.test.*|*.spec.*|*Tests.*|*tests/*)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# ── Check if a file is a public API file ──────────────────────────────────────
is_public_api() {
  local file="$1"
  case "$file" in
    *[Cc]ontroller*|*[Hh]andler*|*[Ee]ndpoint*|*[Rr]oute*|*[Rr]outer*|*api/*|*API/*)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# ── Resolve file path relative to project dir ─────────────────────────────────
resolve_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    echo "$f"
  elif [[ -f "${PROJECT_DIR}/${f}" ]]; then
    echo "${PROJECT_DIR}/${f}"
  else
    echo "$f"
  fi
}

# ── Cache helpers ─────────────────────────────────────────────────────────────
compute_cache_key() {
  local key=""
  for f in "${TARGET_FILES[@]}"; do
    local resolved
    resolved=$(resolve_file "$f")
    if [[ -f "$resolved" ]]; then
      key+=$(sha256sum "$resolved" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$resolved" 2>/dev/null | awk '{print $1}')
    else
      key+="missing:$f"
    fi
  done
  echo "$key" | sha256sum 2>/dev/null | awk '{print $1}' || echo "$key" | shasum -a 256 2>/dev/null | awk '{print $1}'
}

get_cache_dir() {
  local cache_dir="${PROJECT_DIR}/output/dev-sessions/.impact-cache"
  # Try to create the cache dir; fall back to /tmp if it fails
  if mkdir -p "$cache_dir" 2>/dev/null; then
    echo "$cache_dir"
  else
    cache_dir="/tmp/impact-analysis-cache"
    mkdir -p "$cache_dir" 2>/dev/null || true
    echo "$cache_dir"
  fi
}

check_cache() {
  local cache_key="$1"
  local cache_dir
  cache_dir=$(get_cache_dir)
  local cache_file="${cache_dir}/${cache_key}.md"
  if [[ -f "$cache_file" ]]; then
    cat "$cache_file"
    return 0
  fi
  return 1
}

save_cache() {
  local cache_key="$1"
  local content="$2"
  local cache_dir
  cache_dir=$(get_cache_dir)
  mkdir -p "$cache_dir" 2>/dev/null || true
  echo "$content" > "${cache_dir}/${cache_key}.md" 2>/dev/null || true
}

# ── Main analysis ─────────────────────────────────────────────────────────────
run_analysis() {
  # Use temp files to store results (avoids set -u issues with empty arrays)
  local direct_file transitive_file tests_file seen_file
  direct_file=$(mktemp)
  transitive_file=$(mktemp)
  tests_file=$(mktemp)
  seen_file=$(mktemp)

  # Cleanup on exit
  trap "rm -f '$direct_file' '$transitive_file' '$tests_file' '$seen_file'" RETURN

  # Mark target files as seen to avoid cycles
  for tf in "${TARGET_FILES[@]}"; do
    echo "$tf" >> "$seen_file"
  done

  is_seen() { grep -qxF "$1" "$seen_file" 2>/dev/null; }
  mark_seen() { echo "$1" >> "$seen_file"; }

  # Depth 1: find direct dependents of each target
  for tf in "${TARGET_FILES[@]}"; do
    local lang
    lang=$(detect_language "$tf")
    local deps
    deps=$(find_dependents "$tf" "$lang")
    while IFS= read -r dep; do
      [[ -z "$dep" ]] && continue
      # Normalize path
      dep="${dep#${PROJECT_DIR}/}"
      if ! is_seen "$dep"; then
        if is_test_file "$dep"; then
          printf '%s\t%s\n' "$dep" "$tf" >> "$tests_file"
        else
          printf '%s\t%s\n' "$dep" "$tf" >> "$direct_file"
          mark_seen "$dep"
        fi
      fi
    done <<< "$deps"
  done

  # Depth 2+: find transitive dependents
  if [[ "$MAX_DEPTH" -ge 2 ]]; then
    local current_file next_file
    current_file=$(mktemp)
    next_file=$(mktemp)
    trap "rm -f '$direct_file' '$transitive_file' '$tests_file' '$seen_file' '$current_file' '$next_file'" RETURN

    # Seed with direct deps
    if [[ -s "$direct_file" ]]; then
      awk -F'\t' '{print $1}' "$direct_file" > "$current_file"
    fi

    local depth=2
    while [[ $depth -le $MAX_DEPTH ]] && [[ -s "$current_file" ]]; do
      : > "$next_file"
      while IFS= read -r dep; do
        [[ -z "$dep" ]] && continue
        local dep_lang
        dep_lang=$(detect_language "$dep")
        local sub_deps
        sub_deps=$(find_dependents "$dep" "$dep_lang")
        while IFS= read -r sdep; do
          [[ -z "$sdep" ]] && continue
          sdep="${sdep#${PROJECT_DIR}/}"
          if ! is_seen "$sdep"; then
            if is_test_file "$sdep"; then
              printf '%s\t%s (transitive)\n' "$sdep" "$dep" >> "$tests_file"
            else
              printf '%s\t%s\n' "$sdep" "$dep" >> "$transitive_file"
              mark_seen "$sdep"
              echo "$sdep" >> "$next_file"
            fi
          fi
        done <<< "$sub_deps"
      done < "$current_file"
      cp "$next_file" "$current_file"
      ((depth++))
    done
    rm -f "$current_file" "$next_file"
  fi

  # Also search for tests that directly import target files
  if [[ "$INCLUDE_TESTS" == "true" ]]; then
    for tf in "${TARGET_FILES[@]}"; do
      local lang
      lang=$(detect_language "$tf")
      local module_name
      module_name=$(extract_module_name "$tf")
      local pattern
      pattern=$(build_import_pattern "$module_name" "$lang" "$tf")
      if [[ -n "$pattern" ]]; then
        local test_hits
        test_hits=$(grep -rlE "$pattern" "$PROJECT_DIR" \
          --include='*.test.*' --include='*.spec.*' --include='*_test.*' \
          --include='*Test.*' --include='*Tests.*' \
          2>/dev/null | grep -vE "(${EXCLUDE_DIRS})" | sort -u || true)
        while IFS= read -r th; do
          [[ -z "$th" ]] && continue
          th="${th#${PROJECT_DIR}/}"
          if ! grep -qF "$th" "$tests_file" 2>/dev/null; then
            printf '%s\t%s\n' "$th" "$tf" >> "$tests_file"
          fi
        done <<< "$test_hits"
      fi
    done
  fi

  # ── Count results ──────────────────────────────────────────────────────────
  local direct_count=0 transitive_count=0 test_count=0 public_api_count=0

  if [[ -s "$direct_file" ]]; then
    direct_count=$(wc -l < "$direct_file" | tr -d ' ')
  fi
  if [[ -s "$transitive_file" ]]; then
    transitive_count=$(wc -l < "$transitive_file" | tr -d ' ')
  fi
  if [[ -s "$tests_file" ]]; then
    test_count=$(wc -l < "$tests_file" | tr -d ' ')
  fi

  # Count public API files
  if [[ -s "$direct_file" ]]; then
    while IFS=$'\t' read -r d _rel; do
      if is_public_api "$d"; then
        ((public_api_count++)) || true
      fi
    done < "$direct_file"
  fi
  for tf in "${TARGET_FILES[@]}"; do
    if is_public_api "$tf"; then
      ((public_api_count++)) || true
    fi
  done

  # ── Risk scoring ────────────────────────────────────────────────────────────
  local risk_score=$(( (direct_count * 15) + (transitive_count * 5) + (test_count * 10) + (public_api_count * 20) ))
  [[ $risk_score -gt 100 ]] && risk_score=100

  local risk_label="LOW"
  local risk_recommendation=""
  if [[ $risk_score -ge 76 ]]; then
    risk_label="CRITICAL"
    risk_recommendation="Consider splitting this slice into smaller sub-slices"
  elif [[ $risk_score -ge 51 ]]; then
    risk_label="HIGH"
    risk_recommendation="Careful review recommended before implementation"
  elif [[ $risk_score -ge 26 ]]; then
    risk_label="MEDIUM"
    risk_recommendation="Run affected tests after implementation"
  else
    risk_recommendation="Low impact change, standard verification sufficient"
  fi

  # ── Generate report ─────────────────────────────────────────────────────────
  local report=""
  report+="# Impact Analysis"$'\n'
  report+=""$'\n'

  # Direct files
  report+="## Direct files"$'\n'
  for tf in "${TARGET_FILES[@]}"; do
    report+="- ${tf} — target"$'\n'
  done
  report+=""$'\n'

  # Impacted files
  report+="## Impacted files"$'\n'
  if [[ $direct_count -eq 0 && $transitive_count -eq 0 ]]; then
    report+="No dependent files found."$'\n'
  else
    report+="| File | Relation | Risk |"$'\n'
    report+="|------|----------|------|"$'\n'
    if [[ -s "$direct_file" ]]; then
      while IFS=$'\t' read -r d drel; do
        local drisk="MEDIUM"
        is_public_api "$d" && drisk="HIGH"
        report+="| ${d} | imports ${drel} | ${drisk} |"$'\n'
      done < "$direct_file"
    fi
    if [[ -s "$transitive_file" ]]; then
      while IFS=$'\t' read -r t trel; do
        report+="| ${t} | transitive via ${trel} | LOW |"$'\n'
      done < "$transitive_file"
    fi
  fi
  report+=""$'\n'

  # Affected tests
  report+="## Affected tests"$'\n'
  if [[ $test_count -eq 0 ]]; then
    report+="No affected tests found."$'\n'
  else
    report+="| Test | Covers | Expected |"$'\n'
    report+="|------|--------|----------|"$'\n'
    if [[ -s "$tests_file" ]]; then
      while IFS=$'\t' read -r t tcovers; do
        report+="| ${t} | ${tcovers} | RED if signature changes |"$'\n'
      done < "$tests_file"
    fi
  fi
  report+=""$'\n'

  # Risk score
  report+="## Risk score"$'\n'
  report+="- Score: ${risk_score}/100 (${risk_label})"$'\n'
  report+="- Direct dependents: ${direct_count}"$'\n'
  report+="- Transitive dependents: ${transitive_count}"$'\n'
  report+="- Affected tests: ${test_count}"$'\n'
  report+="- Public API files: ${public_api_count}"$'\n'
  report+="- Recommendation: ${risk_recommendation}"$'\n'
  report+=""$'\n'

  # External dependencies
  report+="## External dependencies"$'\n'
  report+="- None detected (grep-based analysis)"$'\n'

  echo "$report"
}

# ── Entry point ───────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  validate_inputs

  # Resolve project dir to absolute path
  PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)

  # Check cache
  local cache_key
  cache_key=$(compute_cache_key)
  if cached_result=$(check_cache "$cache_key" 2>/dev/null); then
    if [[ -n "$OUTPUT_FILE" ]]; then
      echo "$cached_result" > "$OUTPUT_FILE"
    else
      echo "$cached_result"
    fi
    return 0
  fi

  # Run analysis
  local result
  result=$(run_analysis)

  # Save cache
  save_cache "$cache_key" "$result"

  # Output
  if [[ -n "$OUTPUT_FILE" ]]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")" 2>/dev/null || true
    echo "$result" > "$OUTPUT_FILE"
    echo "Report written to: $OUTPUT_FILE" >&2
  else
    echo "$result"
  fi
}

main "$@"
