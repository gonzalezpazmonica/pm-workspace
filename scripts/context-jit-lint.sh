#!/bin/bash
# context-jit-lint.sh — SE-270 S7: lint agent/skill templates for preloading
# Flags templates that load full content instead of lightweight identifiers.
# Reports tokens saved by switching to Just-In-Time loading.
# Usage:
#   context-jit-lint.sh                    # scan all agents and skills
#   context-jit-lint.sh --dir .opencode/agents
#   context-jit-lint.sh --dir .opencode/skills
#   context-jit-lint.sh --json             # machine-readable output
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

AGENTS_DIR="${WORKSPACE}/.opencode/agents"
SKILLS_DIR="${WORKSPACE}/.opencode/skills"
SCAN_DIR=""
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) SCAN_DIR="${2:-}"; shift 2 ;;
    --json) OUTPUT_JSON=true; shift ;;
    --help|-h)
      echo "context-jit-lint.sh — detect preloading patterns in agent/skill templates"
      echo "Usage: context-jit-lint.sh [--dir PATH] [--json]"
      exit 0 ;;
    *) shift ;;
  esac
done

# ── Preloading patterns to flag ────────────────────────────────────────────────

# Patterns that indicate full content preload instead of JIT reference
PRELOAD_PATTERNS=(
  # Full template/content inlined instead of path reference
  'full.*content.*below|entire.*document|complete.*text'
  # Reading whole files inline
  'read.*entire|load.*full|import.*all'
  # Embedding 3+ levels of detail inline
  '---.*---.*---'  # triple section headers = fat inline
  # Inline code blocks > 10 lines
)

# JIT patterns (good)
JIT_PATTERNS=(
  # Lightweight path references
  '@[a-z][a-z0-9/_.-]+\.md'
  # Function/script invocations with path
  'bash scripts/|python3 scripts/'
  # Use of lazy reference notation
  'bajo demanda|under demand|lazy load|JIT|just.in.time'
)

# Token estimation: ~4 chars = 1 token
estimate_tokens() {
  local text="$1"
  echo $(( ${#text} / 4 ))
}

# ── Scan single file ───────────────────────────────────────────────────────────

scan_file() {
  local file="$1"
  local basename
  basename=$(basename "$file")

  local total_tokens=0
  total_tokens=$(estimate_tokens "$(cat "$file" 2>/dev/null || true)")

  # Count preload patterns
  local preload_hits=0
  local preload_details=""
  for pattern in "${PRELOAD_PATTERNS[@]}"; do
    local hits
    hits=$(grep -i -E "$pattern" "$file" 2>/dev/null | wc -l)
    if [[ "$hits" -gt 0 ]]; then
      preload_hits=$(( preload_hits + hits ))
      preload_details="${preload_details:+$preload_details, }${pattern}:${hits}"
    fi
  done

  # Count JIT patterns
  local jit_hits=0
  local jit_details=""
  for pattern in "${JIT_PATTERNS[@]}"; do
    local hits
    hits=$(grep -E "$pattern" "$file" 2>/dev/null | wc -l)
    if [[ "$hits" -gt 0 ]]; then
      jit_hits=$(( jit_hits + hits ))
      jit_details="${jit_details:+$jit_details, }${pattern}:${hits}"
    fi
  done

  # Estimate preload token cost
  local preload_tokens=0
  if [[ "$preload_hits" -gt 0 ]]; then
    preload_tokens=$(( total_tokens / 2 ))
  fi

  # Classify
  local verdict="OK"
  if [[ "$preload_hits" -gt "$jit_hits" ]]; then
    verdict="PRELOAD"   # More preloading than JIT = flag
  elif [[ "$jit_hits" -gt 0 ]]; then
    verdict="JIT"       # More JIT than preload = good
  elif [[ "$total_tokens" -gt 3000 ]]; then
    verdict="INLINE"    # Large file with no clear loading strategy
  else
    verdict="LIGHT"     # Small enough that preload cost is negligible
  fi

  if $OUTPUT_JSON; then
    echo "{\"file\":\"$file\",\"tokens\":$total_tokens,\"preload_hits\":$preload_hits,\"jit_hits\":$jit_hits,\"preload_tokens_est\":$preload_tokens,\"verdict\":\"$verdict\"}"
  else
    printf "%-6s tokens=%-5d preload=%-2d jit=%-2d -> %s\n" \
      "[$verdict]" "$total_tokens" "$preload_hits" "$jit_hits" "$file"
  fi
}

# ── Scan directory ─────────────────────────────────────────────────────────────

scan_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "Directory not found: $dir" >&2
    return
  fi

  local scanned=0 preload_files=0 jit_files=0 light_files=0 inline_files=0
  local total_tokens_all=0 total_preload_tokens=0

  while IFS= read -r -d '' file; do
    [[ "$file" == */SKILL.md || "$file" == */CLAUDE.md || "$file" == *.md ]] || continue
    [[ "$file" == */_* ]] && continue  # skip templates/underscore dirs

    scanned=$(( scanned + 1 ))
    local result
    result=$(scan_file "$file")
    echo "$result"

    local v
    v=$(echo "$result" | awk '{print $1}')
    case "$v" in
      "[PRELOAD]") preload_files=$(( preload_files + 1 )) ;;
      "[JIT]") jit_files=$(( jit_files + 1 )) ;;
      "[LIGHT]") light_files=$(( light_files + 1 )) ;;
      "[INLINE]") inline_files=$(( inline_files + 1 )) ;;
    esac

    # Extract token counts
    local tokens
    tokens=$(echo "$result" | grep -oP 'tokens=\K[0-9]+' || echo 0)
    total_tokens_all=$(( total_tokens_all + tokens ))
    local pt
    pt=$(echo "$result" | grep -oP 'preload_tokens_est=\K[0-9]+' || echo 0)
    total_preload_tokens=$(( total_preload_tokens + pt ))
  done < <(find "$dir" -type f -name "*.md" -print0 2>/dev/null)

  local total_no_jit=$(( preload_files + inline_files ))
  local savings_est=0
  if [[ "$total_no_jit" -gt 0 ]]; then
    savings_est=$(( total_preload_tokens * 40 / 100 ))
  fi

  echo ""
  echo "=== JIT Lint Summary: $(basename "$dir") ==="
  echo "  scanned:       $scanned"
  echo "  PRELOAD flag:  $preload_files"
  echo "  INLINE (large): $inline_files"
  echo "  JIT (good):    $jit_files"
  echo "  LIGHT (ok):    $light_files"
  echo "  total tokens:  $total_tokens_all"
  echo "  est preload:   $total_preload_tokens"
  echo "  est savings:   ~${savings_est} tokens (40% reduction with JIT)"
  echo ""
}

# ── Main ───────────────────────────────────────────────────────────────────────

if $OUTPUT_JSON; then
  echo '{"entries":['
  first=true  # Using integer flag for portability
fi

if [[ -n "$SCAN_DIR" ]]; then
  scan_dir "$SCAN_DIR"
elif $OUTPUT_JSON; then
  # JSON mode: scan both dirs
  scan_dir "$AGENTS_DIR"
  scan_dir "$SKILLS_DIR"
  echo ']}'
else
  echo "=== Context JIT Lint — SE-270 S7 ==="
  echo ""
  echo "## Agents"
  scan_dir "$AGENTS_DIR"
  echo ""
  echo "## Skills"
  scan_dir "$SKILLS_DIR"
fi

exit 0
