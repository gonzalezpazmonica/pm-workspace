#!/bin/bash
# skill-loader.sh — SPEC-144: Context-Aware Skill Loading
# Selects relevant skills by keyword scoring, respecting a token budget.
# Usage: bash scripts/skill-loader.sh --task "descripción" [--budget N] [--manifest path]
# Output: list of SKILL.md paths (one per line) to stdout
set -euo pipefail

MANIFEST="${MANIFEST_PATH:-}"
TASK=""
BUDGET=2000
MIN_SCORE=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)   TASK="$2";   shift 2 ;;
    --budget) BUDGET="$2"; shift 2 ;;
    --manifest) MANIFEST="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[[ -z "$TASK" ]] && { echo "Error: --task required" >&2; exit 1; }

# Locate manifest
if [[ -z "$MANIFEST" ]]; then
  for candidate in \
    "$(dirname "${BASH_SOURCE[0]}")/../.claude/skill-manifests.json" \
    ".claude/skill-manifests.json" \
    "$HOME/claude/.claude/skill-manifests.json"; do
    if [[ -f "$candidate" ]]; then
      MANIFEST="$candidate"
      break
    fi
  done
fi

if [[ -z "$MANIFEST" || ! -f "$MANIFEST" ]]; then
  echo "[skill-loader] No manifest found. Run scripts/build-skill-manifest.sh first." >&2
  exit 0
fi

if [[ -z "$TASK" ]]; then
  echo "[skill-loader] --task is required." >&2
  exit 1
fi

python3 - <<PYEOF
import json, re, sys

manifest_path = "$MANIFEST"
task          = """$TASK"""
budget        = int("$BUDGET")
min_score     = int("$MIN_SCORE")

with open(manifest_path) as f:
    data = json.load(f)

skills = data.get("skills", [])

# Tokenize task description into keywords (lowercase, 3+ chars)
keywords = set(w.lower() for w in re.findall(r"[a-zA-ZáéíóúñüÁÉÍÓÚÑÜ]{3,}", task))

# Score each skill: count keyword hits in name + description + category
scored = []
for s in skills:
    text = " ".join([
        s.get("name", ""),
        s.get("description", ""),
        s.get("category", ""),
    ]).lower()
    score = sum(1 for kw in keywords if kw in text)
    if score >= min_score:
        scored.append((score, s.get("tokens_est", 500), s.get("path", "")))

# Sort by score descending, then tokens ascending (prefer cheap high-score)
scored.sort(key=lambda x: (-x[0], x[1]))

# Greedy token-budget packing
used = 0
paths = []
for score, tokens, path in scored:
    if not path:
        continue
    if used + tokens <= budget:
        paths.append(path)
        used += tokens

for p in paths:
    print(p)
PYEOF
