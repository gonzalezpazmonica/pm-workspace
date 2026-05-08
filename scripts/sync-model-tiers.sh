#!/usr/bin/env bash
# sync-model-tiers.sh — Resolve abstract model tiers (heavy|mid|fast) to provider-
# specific model IDs in command/agent frontmatter.
#
# Reads ~/.savia/preferences.yaml as source of truth.
# Reescribe `model: heavy|mid|fast` -> `model: <provider>/<id>`.
# Idempotente. Re-correr cuando cambies provider o model_*.
#
# Default scope: .claude/commands/*.md, .claude/agents/*.md.
# Override via $1 (path to scan recursively).

set -euo pipefail

PREFS="${SAVIA_PREFS:-$HOME/.savia/preferences.yaml}"
WORKSPACE="${SAVIA_WORKSPACE_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCAN_PATH="${1:-}"

# --- Read preferences -------------------------------------------------------
if [[ ! -f "$PREFS" ]]; then
  echo "ERROR: $PREFS not found. Crea preferences.yaml primero." >&2
  exit 1
fi

# minimal yaml reader (no deps): grab `model_<tier>: <value>` lines
get_pref() {
  local key=$1
  grep -E "^[[:space:]]*${key}:" "$PREFS" \
    | head -1 \
    | sed -E "s/^[[:space:]]*${key}:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//"
}

MODEL_HEAVY=$(get_pref "model_heavy")
MODEL_MID=$(get_pref "model_mid")
MODEL_FAST=$(get_pref "model_fast")

if [[ -z "$MODEL_HEAVY" || -z "$MODEL_MID" || -z "$MODEL_FAST" ]]; then
  echo "ERROR: model_heavy/mid/fast missing in $PREFS" >&2
  exit 1
fi

echo "Resolving tiers from $PREFS:"
echo "  heavy -> $MODEL_HEAVY"
echo "  mid   -> $MODEL_MID"
echo "  fast  -> $MODEL_FAST"
echo

# --- Scope ------------------------------------------------------------------
if [[ -n "$SCAN_PATH" ]]; then
  TARGETS=("$SCAN_PATH")
else
  TARGETS=(
    "$WORKSPACE/.claude/commands"
    "$WORKSPACE/.claude/agents"
  )
fi

# --- Rewrite ----------------------------------------------------------------
# Only touch lines starting with `model: ` AND value is exactly heavy|mid|fast.
# Preserves files where model is already a full ID like `github-copilot/...`.

count_total=0
count_changed=0
declare -A counters=( [heavy]=0 [mid]=0 [fast]=0 )

for target in "${TARGETS[@]}"; do
  [[ -d "$target" ]] || { echo "skip (not a dir): $target"; continue; }

  while IFS= read -r -d '' file; do
    count_total=$((count_total + 1))

    # Only process if file has frontmatter starting at line 1
    head -1 "$file" | grep -q '^---$' || continue

    # Extract `model:` from frontmatter (lines 1..second `---`)
    current=$(awk '/^---$/{c++; next} c==1 && /^model:/ {sub(/^model:[[:space:]]*/,""); print; exit}' "$file")
    [[ -z "$current" ]] && continue

    # Strip optional comments and whitespace
    current_clean=$(echo "$current" | sed -E 's/[[:space:]]*#.*$//; s/[[:space:]]*$//; s/^[[:space:]]*//')

    case "$current_clean" in
      heavy|mid|fast)
        case "$current_clean" in
          heavy) new="$MODEL_HEAVY" ;;
          mid)   new="$MODEL_MID" ;;
          fast)  new="$MODEL_FAST" ;;
        esac
        # Replace ONLY first model: line within frontmatter (top of file)
        # Use awk to scope to frontmatter and preserve everything else
        awk -v new="$new" '
          BEGIN { in_fm=0; done=0; fm_count=0 }
          /^---$/ {
            fm_count++
            if (fm_count == 1) in_fm = 1
            else if (fm_count == 2) in_fm = 0
            print; next
          }
          in_fm && !done && /^model:/ {
            print "model: " new
            done = 1
            next
          }
          { print }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        counters[$current_clean]=$(( counters[$current_clean] + 1 ))
        count_changed=$((count_changed + 1))
        ;;
      *)
        # Already a real ID, or empty, or other tier system — skip
        ;;
    esac
  done < <(find "$target" -maxdepth 1 -name "*.md" -type f -print0)
done

echo "Scanned: $count_total .md files"
echo "Rewritten: $count_changed (heavy=${counters[heavy]} mid=${counters[mid]} fast=${counters[fast]})"
echo
echo "Done. To verify: grep -rE '^model: (heavy|mid|fast)$' .claude/commands .claude/agents"
