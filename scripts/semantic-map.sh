#!/usr/bin/env bash
# semantic-map.sh — Generate compressed semantic maps of source code files
# SPEC: SPEC-SEMANTIC-CONTEXT-MAPS
#
# Usage: bash scripts/semantic-map.sh [options] <file1> [file2] [...]
#
# Options:
#   --format compact|full    Output detail level. Default: compact
#   --lang auto|ts|cs|py|go|rs|java   Language override. Default: auto
#   --output-dir DIR         Write .smap files to DIR. Default: stdout
#   --max-tokens N           Target max tokens per file. Default: 300

set -uo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
FORMAT="compact"
LANG_OVERRIDE="auto"
OUTPUT_DIR=""
MAX_TOKENS=300
FILES=()

# ── Parse arguments ───────────────────────────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format)
        FORMAT="${2:-compact}"
        shift 2
        ;;
      --lang)
        LANG_OVERRIDE="${2:-auto}"
        shift 2
        ;;
      --output-dir)
        OUTPUT_DIR="${2:-}"
        shift 2
        ;;
      --max-tokens)
        MAX_TOKENS="${2:-300}"
        shift 2
        ;;
      --)
        shift
        FILES+=("$@")
        break
        ;;
      -*)
        echo "Error: Unknown option: $1" >&2
        exit 1
        ;;
      *)
        FILES+=("$1")
        shift
        ;;
    esac
  done
}

# ── Language detection ────────────────────────────────────────────────────────
detect_language() {
  local file="$1"
  if [[ "$LANG_OVERRIDE" != "auto" ]]; then
    echo "$LANG_OVERRIDE"
    return
  fi
  case "${file##*.}" in
    ts|tsx|mts|cts) echo "ts" ;;
    cs)             echo "cs" ;;
    py)             echo "py" ;;
    go)             echo "go" ;;
    rs)             echo "rs" ;;
    java)           echo "java" ;;
    *)              echo "unknown" ;;
  esac
}

# ── SHA256 hash (first 8 chars) ──────────────────────────────────────────────
file_hash() {
  local file="$1"
  if command -v sha256sum &>/dev/null; then
    sha256sum "$file" | cut -c1-8
  elif command -v shasum &>/dev/null; then
    shasum -a 256 "$file" | cut -c1-8
  else
    # Fallback: use cksum + wc
    echo "nohash00"
  fi
}

# ── Cache lookup ──────────────────────────────────────────────────────────────
check_cache() {
  local hash="$1" cache_dir="$2"
  local cache_file="${cache_dir}/${hash}.smap"
  if [[ -n "$cache_dir" && -f "$cache_file" ]]; then
    cat "$cache_file"
    return 0
  fi
  return 1
}

write_cache() {
  local hash="$1" cache_dir="$2" content="$3"
  if [[ -n "$cache_dir" ]]; then
    mkdir -p "$cache_dir"
    printf '%s\n' "$content" > "${cache_dir}/${hash}.smap"
  fi
}

# ── Extraction: TypeScript ────────────────────────────────────────────────────
extract_ts_exports() {
  local file="$1"
  grep -n '^\s*export\s\+' "$file" 2>/dev/null | \
    grep -E '(class|function|const|let|type|interface|enum|async)\s' | \
    sed 's/^\([0-9]*\):\s*//' | \
    sed 's/export\s\+default\s\+/export /' | \
    sed 's/{.*//' | \
    sed 's/\s*$//' | \
    head -40
}

extract_ts_deps() {
  local file="$1"
  grep -E "^\s*(import|require)\s" "$file" 2>/dev/null | \
    sed "s/.*from\s*['\"]//; s/['\"].*//" | \
    sed "s/.*require(['\"]//; s/['\"]).*//" | \
    sort -u | \
    head -30
}

# ── Extraction: C# ───────────────────────────────────────────────────────────
extract_cs_exports() {
  local file="$1"
  grep -nE '^\s*public\s+(static\s+)?(class|interface|record|enum|struct|async\s)' "$file" 2>/dev/null | \
    sed 's/^\([0-9]*\):\s*//' | sed 's/{.*//' | sed 's/\s*$//' | head -20
  grep -nE '^\s*public\s+(static\s+)?(async\s+)?(override\s+)?(virtual\s+)?\w+[\<\[]?' "$file" 2>/dev/null | \
    grep -vE '(class|interface|record|enum|struct)\s' | \
    grep -E '\(' | \
    sed 's/^\([0-9]*\):\s*//' | sed 's/{.*//' | sed 's/\s*$//' | head -30
}

extract_cs_deps() {
  local file="$1"
  grep -E '^\s*using\s' "$file" 2>/dev/null | \
    sed 's/using\s\+static\s\+//; s/using\s\+//; s/\s*;.*//' | \
    sort -u | head -30
}

# ── Extraction: Python ────────────────────────────────────────────────────────
extract_py_exports() {
  local file="$1"
  # Match class/def/async def at any indentation level (public in Python = not starting with _)
  grep -nE '^[[:space:]]*(class[[:space:]]|def[[:space:]]|async[[:space:]]+def[[:space:]])' "$file" 2>/dev/null | \
    grep -vE '[[:space:]]+def[[:space:]]+_' | \
    grep -vE '^\s*#' | \
    sed 's/^[0-9]*:[[:space:]]*//' | sed 's/:[[:space:]]*$//' | sed 's/[[:space:]]*$//' | head -40
}

extract_py_deps() {
  local file="$1"
  grep -E '^\s*(import|from)\s' "$file" 2>/dev/null | \
    sed 's/from\s\+//; s/\s\+import.*//; s/import\s\+//; s/\s*,/\n/g' | \
    sed 's/\s*$//' | sort -u | head -30
}

# ── Extraction: Go ────────────────────────────────────────────────────────────
extract_go_exports() {
  local file="$1"
  # Exported = starts with uppercase after func/type/var/const
  grep -nE '^(func|type|var|const)\s+[A-Z]' "$file" 2>/dev/null | \
    sed 's/^\([0-9]*\):\s*//' | sed 's/{.*//' | sed 's/\s*$//' | head -40
}

extract_go_deps() {
  local file="$1"
  # Extract all quoted strings from import blocks
  # Strategy: find the import block, then extract quoted strings
  local in_block=false
  local deps=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Detect start of import block
    if [[ "$line" =~ ^import[[:space:]]*\( ]]; then
      in_block=true
      continue
    fi
    # Detect end of import block
    if [[ "$in_block" == "true" ]] && [[ "$line" =~ ^\) ]]; then
      in_block=false
      continue
    fi
    # Extract quoted string from import block
    if [[ "$in_block" == "true" ]] && [[ "$line" == *'"'* ]]; then
      local dep
      dep=$(echo "$line" | sed 's/[^"]*"//; s/".*//')
      if [[ -n "$dep" ]]; then
        deps+="$dep"$'\n'
      fi
    fi
    # Single-line import
    if [[ "$in_block" == "false" ]] && [[ "$line" =~ ^[[:space:]]*import[[:space:]]+\" ]]; then
      local dep
      dep=$(echo "$line" | sed 's/[^"]*"//; s/".*//')
      if [[ -n "$dep" ]]; then
        deps+="$dep"$'\n'
      fi
    fi
  done < "$file"
  if [[ -n "$deps" ]]; then
    echo "$deps" | sort -u | head -30
  fi
}

# ── Extraction: Rust ──────────────────────────────────────────────────────────
extract_rs_exports() {
  local file="$1"
  grep -nE '^\s*pub\s+(fn|struct|enum|trait|mod|type|const|static)\s' "$file" 2>/dev/null | \
    sed 's/^\([0-9]*\):\s*//' | sed 's/{.*//' | sed 's/\s*$//' | head -40
}

extract_rs_deps() {
  local file="$1"
  grep -E '^\s*use\s' "$file" 2>/dev/null | \
    sed 's/use\s\+//; s/\s*;.*//' | sort -u | head -30
}

# ── Extraction: Java ──────────────────────────────────────────────────────────
extract_java_exports() {
  local file="$1"
  grep -nE '^\s*public\s+(static\s+)?(abstract\s+)?(class|interface|record|enum)\s' "$file" 2>/dev/null | \
    sed 's/^\([0-9]*\):\s*//' | sed 's/{.*//' | sed 's/\s*$//' | head -20
  grep -nE '^\s*public\s+(static\s+)?(synchronized\s+)?(abstract\s+)?\w+[\<\[]?' "$file" 2>/dev/null | \
    grep -vE '(class|interface|record|enum)\s' | \
    grep -E '\(' | \
    sed 's/^\([0-9]*\):\s*//' | sed 's/{.*//' | sed 's/\s*$//' | head -30
}

extract_java_deps() {
  local file="$1"
  grep -E '^\s*import\s' "$file" 2>/dev/null | \
    sed 's/import\s\+static\s\+//; s/import\s\+//; s/\s*;.*//' | \
    sort -u | head -30
}

# ── Pattern detection ─────────────────────────────────────────────────────────
detect_patterns() {
  local file="$1"
  local patterns=()
  local content
  content=$(cat "$file" 2>/dev/null)

  # Repository pattern
  if echo "$content" | grep -qiE '(repository|Repository|IRepository|repo)'; then
    patterns+=("Repository pattern")
  fi

  # Dependency injection
  if echo "$content" | grep -qiE '(inject|@Inject|constructor\(|IServiceProvider|Dependency Injection|@autowired|@Service|@Component)'; then
    patterns+=("Dependency injection")
  fi

  # Cache-aside
  if echo "$content" | grep -qiE '(cache|Cache|redis|memcached|IDistributedCache|CacheService)'; then
    patterns+=("Cache-aside pattern")
  fi

  # Observer/Events
  if echo "$content" | grep -qiE '(EventEmitter|EventBus|addEventListener|on\(|emit\(|@EventHandler|INotification|Observer)'; then
    patterns+=("Observer/Event pattern")
  fi

  # Factory
  if echo "$content" | grep -qiE '(Factory|factory|create[A-Z]|newInstance|Build\()'; then
    patterns+=("Factory pattern")
  fi

  # Middleware/Pipeline
  if echo "$content" | grep -qiE '(middleware|Middleware|pipeline|Pipeline|UseMiddleware|IMiddleware)'; then
    patterns+=("Middleware/Pipeline pattern")
  fi

  # Strategy
  if echo "$content" | grep -qiE '(Strategy|IStrategy|strategy)'; then
    patterns+=("Strategy pattern")
  fi

  # Singleton
  if echo "$content" | grep -qiE '(Singleton|getInstance|_instance)'; then
    patterns+=("Singleton pattern")
  fi

  for p in "${patterns[@]+"${patterns[@]}"}"; do
    echo "$p"
  done
}

# ── Extension points detection ────────────────────────────────────────────────
detect_extension_points() {
  local file="$1" lang="$2"
  local points=()

  case "$lang" in
    ts)
      # Interface-based extension
      if grep -qE 'interface\s+\w+' "$file" 2>/dev/null; then
        points+=("Interface-based extension (swappable implementations)")
      fi
      # Event-based
      if grep -qE '(emit|EventEmitter|addEventListener)' "$file" 2>/dev/null; then
        points+=("Event listeners for domain events")
      fi
      ;;
    cs)
      if grep -qE 'interface\s+I\w+' "$file" 2>/dev/null; then
        points+=("Interface-based DI (swappable implementations)")
      fi
      if grep -qE '(virtual|abstract)\s' "$file" 2>/dev/null; then
        points+=("Virtual/abstract methods for inheritance extension")
      fi
      ;;
    py)
      if grep -qE '(ABC|abstractmethod|@abstractmethod)' "$file" 2>/dev/null; then
        points+=("Abstract base classes for extension")
      fi
      ;;
    go)
      if grep -qE '^type\s+\w+\s+interface' "$file" 2>/dev/null; then
        points+=("Interface-based extension")
      fi
      ;;
    rs)
      if grep -qE 'pub\s+trait\s' "$file" 2>/dev/null; then
        points+=("Trait-based extension")
      fi
      ;;
    java)
      if grep -qE 'interface\s+\w+' "$file" 2>/dev/null; then
        points+=("Interface-based extension")
      fi
      if grep -qE '(abstract\s+class|@Override)' "$file" 2>/dev/null; then
        points+=("Abstract class hierarchy")
      fi
      ;;
  esac

  for p in "${points[@]+"${points[@]}"}"; do
    echo "$p"
  done
}

# ── Fallback output ──────────────────────────────────────────────────────────
generate_fallback() {
  local file="$1"
  local filename
  filename=$(basename "$file")
  local line_count
  line_count=$(wc -l < "$file" 2>/dev/null || echo "0")

  local output="# ${filename} — Semantic Map
> fallback: true | lines: ${line_count}
"
  output+="
## Content (first 30 + last 20 lines)
\`\`\`
"
  output+="$(head -30 "$file" 2>/dev/null)"
  output+="
...
"
  output+="$(tail -20 "$file" 2>/dev/null)"
  output+="
\`\`\`"
  echo "$output"
}

# ── Token estimation (1 token ~ 4 chars) ─────────────────────────────────────
estimate_tokens() {
  local text="$1"
  local chars
  chars=$(printf '%s' "$text" | wc -c)
  echo $(( (chars + 3) / 4 ))
}

# ── Truncate to max tokens ───────────────────────────────────────────────────
truncate_to_tokens() {
  local text="$1" max_tokens="$2"
  local max_chars=$(( max_tokens * 4 ))
  local current_chars
  current_chars=$(printf '%s' "$text" | wc -c)
  if [[ "$current_chars" -le "$max_chars" ]]; then
    echo "$text"
  else
    printf '%s' "$text" | head -c "$max_chars"
    echo ""
    echo "... (truncated to ~${max_tokens} tokens)"
  fi
}

# ── Generate semantic map for one file ────────────────────────────────────────
generate_map() {
  local file="$1"
  local filename
  filename=$(basename "$file")
  local lang
  lang=$(detect_language "$file")
  local line_count
  line_count=$(wc -l < "$file" 2>/dev/null || echo "0")

  # SCM-01: short file bypass
  if [[ "$line_count" -lt 50 ]]; then
    cat "$file"
    return 0
  fi

  # Unknown language → fallback
  if [[ "$lang" == "unknown" ]]; then
    generate_fallback "$file"
    return 0
  fi

  # Extract exports
  local exports=""
  case "$lang" in
    ts)   exports=$(extract_ts_exports "$file") ;;
    cs)   exports=$(extract_cs_exports "$file") ;;
    py)   exports=$(extract_py_exports "$file") ;;
    go)   exports=$(extract_go_exports "$file") ;;
    rs)   exports=$(extract_rs_exports "$file") ;;
    java) exports=$(extract_java_exports "$file") ;;
  esac

  # Extract dependencies
  local deps=""
  case "$lang" in
    ts)   deps=$(extract_ts_deps "$file") ;;
    cs)   deps=$(extract_cs_deps "$file") ;;
    py)   deps=$(extract_py_deps "$file") ;;
    go)   deps=$(extract_go_deps "$file") ;;
    rs)   deps=$(extract_rs_deps "$file") ;;
    java) deps=$(extract_java_deps "$file") ;;
  esac

  # Count exports and deps
  local export_count=0 dep_count=0
  if [[ -n "$exports" ]]; then
    export_count=$(echo "$exports" | wc -l)
  fi
  if [[ -n "$deps" ]]; then
    dep_count=$(echo "$deps" | wc -l)
  fi

  # Detect patterns
  local patterns
  patterns=$(detect_patterns "$file")

  # Detect extension points
  local ext_points
  ext_points=$(detect_extension_points "$file" "$lang")

  # Build output
  local output="# ${filename} — Semantic Map
> lang: ${lang} | lines: ${line_count} | exports: ${export_count} | deps: ${dep_count}"

  if [[ -n "$exports" ]]; then
    output+="

## Public Interface"
    while IFS= read -r line; do
      output+="
- ${line}"
    done <<< "$exports"
  fi

  if [[ -n "$deps" ]]; then
    output+="

## Dependencies"
    while IFS= read -r line; do
      output+="
- ${line}"
    done <<< "$deps"
  fi

  if [[ -n "$patterns" ]]; then
    output+="

## Architecture Patterns"
    while IFS= read -r line; do
      output+="
- ${line}"
    done <<< "$patterns"
  fi

  if [[ -n "$ext_points" ]]; then
    output+="

## Extension Points"
    while IFS= read -r line; do
      output+="
- ${line}"
    done <<< "$ext_points"
  fi

  # Truncate if exceeds max tokens
  output=$(truncate_to_tokens "$output" "$MAX_TOKENS")

  echo "$output"
}

# ── Process a single file ────────────────────────────────────────────────────
process_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "Error: File not found: $file" >&2
    return 1
  fi

  # Check if binary (not text)
  if file "$file" 2>/dev/null | grep -q 'binary\|ELF\|Mach-O' && \
     ! file "$file" 2>/dev/null | grep -qi 'text'; then
    generate_fallback "$file"
    return 0
  fi

  local hash
  hash=$(file_hash "$file")

  # Check cache
  if [[ -n "$OUTPUT_DIR" ]]; then
    if check_cache "$hash" "$OUTPUT_DIR"; then
      return 0
    fi
  fi

  # Generate map
  local result
  result=$(generate_map "$file")

  # Write to cache or stdout
  if [[ -n "$OUTPUT_DIR" ]]; then
    write_cache "$hash" "$OUTPUT_DIR" "$result"
    echo "$result"
  else
    echo "$result"
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"

  if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "Usage: bash scripts/semantic-map.sh [options] <file1> [file2] [...]" >&2
    echo "Options:" >&2
    echo "  --format compact|full    Output detail level. Default: compact" >&2
    echo "  --lang auto|ts|cs|py|go|rs|java   Language override. Default: auto" >&2
    echo "  --output-dir DIR         Write .smap files to DIR. Default: stdout" >&2
    echo "  --max-tokens N           Target max tokens per file. Default: 300" >&2
    exit 1
  fi

  local first=true
  for file in "${FILES[@]}"; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      echo ""
      echo "---"
      echo ""
    fi
    process_file "$file"
  done
}

main "$@"
