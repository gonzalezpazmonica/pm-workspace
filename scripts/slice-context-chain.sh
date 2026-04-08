#!/usr/bin/env bash
set -uo pipefail

# slice-context-chain.sh — Knowledge chain between dev-session slices
# SPEC-096: Inject completion summaries of prior slices as context.
# Inspired by Anvil (ppazosp/anvil) blocker-as-context pattern.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_CHAIN_WORDS=500

# ── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: slice-context-chain.sh <command> [options]

Commands:
  build <session-dir>     Build context-chain.md from completed slices
  update <session-dir>    Update chain after completing current slice
  show <session-dir>      Display current context chain
  stats <session-dir>     Show chain statistics (word count, slices covered)

Session directory: output/dev-sessions/{session-id}/
Reads: state.json, validation/slice-*.md, impl/slice-*.md
Writes: context-chain.md
EOF
  exit 1
}

# ── Helpers ──────────────────────────────────────────────────────────────────

# Extract completion summary from a slice's validation and impl files
extract_slice_summary() {
  local session_dir="$1"
  local slice_num="$2"

  local impl_file="$session_dir/impl/slice-${slice_num}.md"
  local validation_file="$session_dir/validation/slice-${slice_num}.md"
  local slice_file="$session_dir/slices/slice-${slice_num}.md"

  # Get slice name from state.json
  local slice_name=""
  if [[ -f "$session_dir/state.json" ]]; then
    slice_name=$(python3 -c "
import json, sys
data = json.load(open('$session_dir/state.json'))
for s in data.get('slices', []):
    if s.get('id') == $slice_num:
        print(s.get('name', 'Slice $slice_num'))
        break
" 2>/dev/null || echo "Slice $slice_num")
  fi

  # Extract files from impl
  local files=""
  if [[ -f "$impl_file" ]]; then
    files=$(grep -oE '[A-Z][a-zA-Z]+\.(cs|ts|py|go|rs|java|rb|php)' "$impl_file" 2>/dev/null | sort -u | head -10 | tr '\n' ', ' | sed 's/,$//')
  fi

  # Extract patterns/decisions from impl (look for keywords)
  local patterns=""
  if [[ -f "$impl_file" ]]; then
    patterns=$(grep -iE '(pattern|approach|chose|decided|using|convention|strategy)' "$impl_file" 2>/dev/null | head -3 | sed 's/^[[:space:]]*/  - /')
  fi

  # Extract interfaces (public methods/classes)
  local interfaces=""
  if [[ -f "$impl_file" ]]; then
    interfaces=$(grep -oE '(public|export|def |func |fn )[^{;]+' "$impl_file" 2>/dev/null | head -5 | sed 's/^[[:space:]]*/  - /')
  fi

  # Build summary
  cat <<EOF
### Slice ${slice_num}: ${slice_name}
**Files**: ${files:-none detected}
${patterns:+**Decisions**:
$patterns}
${interfaces:+**Interfaces**:
$interfaces}
EOF
}

# Build the full context chain
cmd_build() {
  local session_dir="$1"
  [[ ! -d "$session_dir" ]] && { echo "Error: session directory not found: $session_dir" >&2; exit 1; }
  [[ ! -f "$session_dir/state.json" ]] && { echo "Error: state.json not found in $session_dir" >&2; exit 1; }

  # Get completed slices from state.json
  local completed_slices
  completed_slices=$(python3 -c "
import json
data = json.load(open('$session_dir/state.json'))
completed = []
for s in data.get('slices', []):
    if s.get('status') in ('completed', 'verified', 'validated'):
        completed.append(s['id'])
for sid in sorted(completed):
    print(sid)
" 2>/dev/null)

  if [[ -z "$completed_slices" ]]; then
    echo "No completed slices found. Context chain is empty."
    # Write empty chain
    cat > "$session_dir/context-chain.md" <<'EOF'
# Knowledge Chain

No completed slices yet. This file will be populated as slices complete.
EOF
    exit 0
  fi

  # Get session ID
  local session_id
  session_id=$(python3 -c "import json; print(json.load(open('$session_dir/state.json')).get('session_id', 'unknown'))" 2>/dev/null)

  # Build chain header
  local chain_file="$session_dir/context-chain.md"
  {
    echo "# Knowledge Chain — $session_id"
    echo ""
    echo "Context from completed slices. Inject into next slice's subagent."
    echo ""
    echo "## Completed Slice Summaries"
    echo ""

    # Add each completed slice's summary
    while IFS= read -r slice_num; do
      [[ -z "$slice_num" ]] && continue
      extract_slice_summary "$session_dir" "$slice_num"
      echo ""
    done <<< "$completed_slices"
  } > "$chain_file"

  # Check word count and compress if needed
  local word_count
  word_count=$(wc -w < "$chain_file")

  if [[ "$word_count" -gt "$MAX_CHAIN_WORDS" ]]; then
    echo "WARNING: Context chain exceeds ${MAX_CHAIN_WORDS} words ($word_count). Consider manual compression." >&2
  fi

  echo "Context chain built: $chain_file ($word_count words, $(echo "$completed_slices" | wc -l) slices)"
}

# Update chain after completing a slice
cmd_update() {
  local session_dir="$1"
  # Rebuild the entire chain (simple, idempotent)
  cmd_build "$session_dir"
}

# Show current chain
cmd_show() {
  local session_dir="$1"
  local chain_file="$session_dir/context-chain.md"

  if [[ -f "$chain_file" ]]; then
    cat "$chain_file"
  else
    echo "No context chain found. Run 'build' first."
    exit 1
  fi
}

# Show statistics
cmd_stats() {
  local session_dir="$1"
  [[ ! -d "$session_dir" ]] && { echo "Error: session directory not found: $session_dir" >&2; exit 1; }

  local chain_file="$session_dir/context-chain.md"
  local word_count=0
  local line_count=0

  if [[ -f "$chain_file" ]]; then
    word_count=$(wc -w < "$chain_file")
    line_count=$(wc -l < "$chain_file")
  fi

  # Count completed slices
  local completed=0
  local total=0
  if [[ -f "$session_dir/state.json" ]]; then
    completed=$(python3 -c "
import json
data = json.load(open('$session_dir/state.json'))
print(sum(1 for s in data.get('slices', []) if s.get('status') in ('completed', 'verified', 'validated')))
" 2>/dev/null)
    total=$(python3 -c "
import json
data = json.load(open('$session_dir/state.json'))
print(len(data.get('slices', [])))
" 2>/dev/null)
  fi

  local token_est=$((word_count * 4 / 3))

  cat <<EOF
Context Chain Stats — $(basename "$session_dir")
  Slices covered:  $completed / $total
  Words:           $word_count / $MAX_CHAIN_WORDS max
  Lines:           $line_count
  Est. tokens:     ~$token_est
  Chain file:      $chain_file
  Status:          $([ "$word_count" -le "$MAX_CHAIN_WORDS" ] && echo "OK" || echo "OVER BUDGET")
EOF
}

# ── Main ─────────────────────────────────────────────────────────────────────

[[ $# -lt 1 ]] && usage
CMD="$1"; shift

case "$CMD" in
  build|update)
    [[ $# -lt 1 ]] && { echo "Error: $CMD requires <session-dir>"; exit 1; }
    cmd_build "$1"
    ;;
  show)
    [[ $# -lt 1 ]] && { echo "Error: show requires <session-dir>"; exit 1; }
    cmd_show "$1"
    ;;
  stats)
    [[ $# -lt 1 ]] && { echo "Error: stats requires <session-dir>"; exit 1; }
    cmd_stats "$1"
    ;;
  *)
    echo "Unknown command: $CMD" >&2
    usage
    ;;
esac
