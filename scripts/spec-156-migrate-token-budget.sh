#!/usr/bin/env bash
# SPEC-156 — Add token_budget frontmatter to all agents.
# Idempotent: re-runs are no-ops once block is present.
#
# Defaults per tier (Anthropic Effective Agents thesis):
#   fast:  per_invocation=30000  context_window_target=8000   escalation_policy=escalate
#   mid:   per_invocation=60000  context_window_target=15000  escalation_policy=escalate
#   heavy: per_invocation=100000 context_window_target=20000  escalation_policy=block
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="$ROOT_DIR/.claude/agents"

[ -d "$AGENTS_DIR" ] || { echo "ERROR: $AGENTS_DIR not found"; exit 2; }

migrated=0
skipped=0
missing_model=0

for f in "$AGENTS_DIR"/*.md; do
  # Skip if token_budget already declared
  if grep -q '^token_budget:' "$f"; then
    skipped=$((skipped + 1))
    continue
  fi

  # Extract model tier from frontmatter
  tier=$(awk '/^---$/{c++; next} c==1 && /^model:/{print $2; exit}' "$f" | tr -d '"' | tr -d "'")

  case "$tier" in
    fast)  per_inv=30000;  ctx_target=8000;  policy=escalate ;;
    mid)   per_inv=60000;  ctx_target=15000; policy=escalate ;;
    heavy) per_inv=100000; ctx_target=20000; policy=block ;;
    *)
      echo "SKIP  $(basename "$f"): unknown or missing model tier ('$tier')"
      missing_model=$((missing_model + 1))
      continue
      ;;
  esac

  # Insert token_budget block immediately after the `model:` line
  python3 - "$f" "$per_inv" "$ctx_target" "$policy" <<'PY'
import sys, pathlib
path = pathlib.Path(sys.argv[1])
per_inv, ctx_target, policy = sys.argv[2], sys.argv[3], sys.argv[4]
lines = path.read_text().splitlines(keepends=True)
out = []
inserted = False
in_fm = False
fm_count = 0
for line in lines:
    out.append(line)
    if line.rstrip() == "---":
        fm_count += 1
        in_fm = fm_count == 1
        continue
    if not inserted and in_fm and line.startswith("model:"):
        out.append(f"token_budget:\n")
        out.append(f"  per_invocation: {per_inv}\n")
        out.append(f"  context_window_target: {ctx_target}\n")
        out.append(f"  escalation_policy: {policy}\n")
        inserted = True
path.write_text("".join(out))
PY

  migrated=$((migrated + 1))
done

echo "SPEC-156 migration complete"
echo "  migrated:      $migrated"
echo "  skipped:       $skipped (already had token_budget)"
echo "  missing_model: $missing_model"
